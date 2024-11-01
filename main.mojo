from algorithm.functional import parallelize
from benchmark import keep
from memory import UnsafePointer


@value
@register_passable("trivial")
struct Measurement:
    var hash_repr: UInt64
    var num: Int16


fn process_line(chars: UnsafePointer[UInt8], offset: Int) -> Measurement:
    alias `;` = Byte(ord(";"))
    alias `.` = Byte(ord("."))
    alias `-` = Byte(ord("-"))
    alias `\n` = Byte(ord("\n"))

    name_start = offset + 1
    name_len = 0

    # TODO: progressive hash
    hash_repr = 0

    alias max_bytes_name_len = 24
    alias simd_width = 4  # min 6 character line length
    for i in range(max_bytes_name_len // simd_width):
        previous = i * simd_width
        has_semicolon = (chars + name_start + previous).load[
            width=simd_width
        ]() == `;`
        alias indexes = SIMD[DType.uint8, simd_width](0, 1, 2, 3)
        if has_semicolon.reduce_or():
            idx = (has_semicolon.cast[DType.uint8]() * indexes).reduce_or()
            name_len = previous + int(idx)
            break

    # FIXME: this part is parsing nonsense. For some reason, even though the
    # previous part gets name_len right, this starts reading before the ;
    num_start = name_start + name_len + 1
    b = (chars + num_start).load[width=1]()
    is_not_neg = int(b != `-`)
    sign = -1 + 2 * is_not_neg
    num = Int16(is_not_neg * int(b ^ 0x30))
    # print("numstart: ", chr(int(b)), num)
    idx = 1

    while b != `\n`:
        idx += 1
        b = (chars + (num_start + idx)).load[width=1]()
        # print(chr(int(b)))
        num = num + int(b != `.`) * (num * 9 + int(b ^ 0x30))

    num *= sign
    # print("num: ", num)
    return Measurement(hash_repr, num)


fn run() raises:
    alias `\n` = Byte(ord("\n"))
    alias amount_lines = 1_000_000_000
    # TODO: can this be autotuned or setup according to CPU L3 cache size?
    alias byte_chunk_size: Int = 2 * 2**20
    """2 MiB."""
    alias max_line_len = 32
    alias min_line_len = 6
    # FIXME: these should be aliases
    var max_iterations = (amount_lines * max_line_len) // byte_chunk_size
    var max_items_per_chunk = byte_chunk_size // min_line_len
    var max_num_measurements = max_items_per_chunk * max_iterations

    leftover_bytes = 0
    # hashes = UnsafePointer[UInt64].alloc(byte_chunk_size)
    # nums = UnsafePointer[UInt16].alloc(byte_chunk_size)
    file = open("./1brc-main/measurements.txt", "rb")
    for chunk in range(max_iterations):
        _ = file.seek(chunk * byte_chunk_size - leftover_bytes)
        data = file.read_bytes(byte_chunk_size)
        size = len(data)
        if size < 1:
            break
        chars = data.unsafe_ptr()
        newline_idx = -1
        for i in reversed(range(size)):
            if chars[i] == `\n`:
                newline_idx = i
                break
        leftover_bytes = size - (newline_idx + 1)

        @parameter
        fn process_lines(i: Int):
            if not (i == 0 or chars[i] == `\n`):
                return
            measurement = process_line(chars, i - int(i == 0))
            keep(measurement)
            # hashes[i] = measurement.hash_repr
            # nums[i] = measurement.num

        # FIXME: parallelize is crashing for some reason
        # parallelize[process_lines](newline_idx - 1)

        for i in range(newline_idx):
            process_lines(i)

        # TODO: find station hash and update values
        # for i in range(newline_idx):

    file.close()

    # print("{", end="")
    # for item in measurements.items():
    #     # TODO: print stuff
    #     pass
    # print("}")


fn main():
    print("starting")
    try:
        run()
        print("finished ok")
    except e:
        print("problem: ")
        print(e)
    finally:
        print("exiting")
