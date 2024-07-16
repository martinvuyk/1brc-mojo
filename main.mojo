from algorithm.functional import parallelize
from bit import count_trailing_zeros
from benchmark import keep

alias b8_semicolon: UInt8 = 0x3B
alias b8_0x01: UInt8 = 0x01
alias b8_0x80: UInt8 = 0x80
alias b64_dot: UInt64 = 0x1010101010101010
alias multiplier = (100 * 0x1000000 + 10 * 0x10000 + 0x1)


@value
@register_passable("trivial")
struct Measurement:
    var hash_repr: UInt64
    var num: Int16


fn process_line(chars: DTypePointer[DType.uint8], offset: Int) -> Measurement:
    var startname = 0
    if offset != 0:
        startname = offset + 1
    var endname = startname

    # TODO: progressive hash
    var hash_repr = 0

    # max 24 byte long name
    var b8 = (chars + startname).simd_strided_load[32](1)
    var diff = b8 ^ b8_semicolon
    var has_semicolon = (diff - b8_0x01) & (~diff & b8_0x80)
    var name_len = count_trailing_zeros(has_semicolon) >> 3
    endname += int(name_len)

    var composite = (chars + startname).bitcast[
        DType.uint64
    ]().simd_strided_load[1](1)
    var signed = (~composite << 59) >> 63
    var mask = ~(signed & 0xFF)
    var tz_dot = count_trailing_zeros(~composite & b64_dot)
    var digits = ((composite & mask) << (28 - tz_dot)) & 0x0F000F0F00
    var value = ((digits * multiplier) >> 32) & 0x3FF
    var num = (value ^ signed) - signed
    return Measurement(hash_repr, num.cast[DType.int16]())


alias eol = String("\n").as_bytes()[0]

alias amount_lines = 1_000_000_000
# TODO: can this be autotuned or setup according to CPU L3 cache size?
alias byte_chunk_size: Int = 2 * 1024
alias max_line_len = 32
alias min_line_len = 6
alias iterations = (amount_lines * max_line_len) // byte_chunk_size
alias max_items_per_chunk = byte_chunk_size // min_line_len
alias max_num_measurements = max_items_per_chunk * iterations


fn run() raises:
    var leftover_bytes = 0
    # var hashes = DTypePointer[DType.uint64].alloc(byte_chunk_size)
    # var nums = DTypePointer[DType.int16].alloc(byte_chunk_size)
    var file = open("./1brc-main/measurements.txt", "rb")
    for chunk in range(iterations):
        _ = file.seek(chunk * byte_chunk_size - leftover_bytes)
        var data = file.read_bytes(byte_chunk_size)
        var size = data.size
        if size == 0:
            break
        var chars = DTypePointer(data.data)
        var upto = size
        if size == byte_chunk_size:
            for i in range(1, max_line_len):
                if data[byte_chunk_size - i] == eol:
                    upto = byte_chunk_size - (i - 1)
                    break
        leftover_bytes = byte_chunk_size - upto

        @parameter
        fn process_lines(i: Int):
            if not (i == 0 or chars[i] == eol):
                return
            var measurement = process_line(chars, i)
            keep(measurement)
            # hashes.store(i, measurement.hash_repr)
            # nums.store(i, measurement.num)

        parallelize[process_lines](upto - 1)
        data.clear()

        # TODO: find station hash and update values
        # for i in range(upto):

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
    except Exception:
        print("problem: ")
        print(Exception)
    finally:
        print("exiting")
