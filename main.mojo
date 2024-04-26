from algorithm.functional import parallelize
from math.bit import cttz
from benchmark import keep

alias b64_semicolon: UInt64 =  0x3B3B3B3B3B3B3B3B
alias b64_0x01: UInt64 = 0x0101010101010101
alias b64_0x80: UInt64 = 0x8080808080808080
alias b64_dot = 0x10101000
alias multiplier = (100 * 0x1000000 + 10 * 0x10000 + 0x1)


# This wasn't used in the end but it's cool nonetheless
@always_inline
fn match_3num(num100: Int = 0, num10: Int = 0, num00: Int = 0) -> Int:
    """Match 3 consecutive UTF-8 number strings to its Int representation."""
    var digits = num100 << 8 | num10 << 16 | num00 << 32
    return (((digits ^ 0x303030) * multiplier) >> 32) & 0x3FF


@value
@register_passable("trivial")
struct Measurement:
    var hash_repr: UInt64
    var num: Int16


@always_inline
fn get_64_p(
    nums: DTypePointer[DType.int8], offset: Int
) -> DTypePointer[DType.uint64]:
    var p = nums.offset(offset).address
    return DTypePointer(p).bitcast[DType.uint64]()


fn process_line(chars: DTypePointer[DType.int8], offset: Int) -> Measurement:
    var startname = 0
    if offset != 0:
        startname = offset + 1
    var endname = startname
    var b64_p = get_64_p(chars, startname)

    # TODO: progressive hash
    var hash_repr = 0

    # max 24 byte long name
    for i in range(3):
        var b64 = b64_p[i]
        var diff = b64 ^ b64_semicolon
        var has_semicolon = (diff - b64_0x01) & (~diff & b64_0x80)
        if has_semicolon != 0:
            var name_len = cttz(has_semicolon) >> 3
            endname = endname + 8 * i + int(name_len)
            break

    var composite = get_64_p(chars, endname)[0]
    var signed = (~composite << 59) >> 63
    var mask = ~(signed & 0xFF)
    var tz_dot = cttz(~composite & b64_dot)
    var digits = ((composite & mask) << (28 - tz_dot)) & 0x0F000F0F00
    var value = ((digits * multiplier) >> 32) & 0x3FF
    var num = (value ^ signed) - signed
    return Measurement(hash_repr, num.cast[DType.int16]())


alias eol = String("\n").as_bytes()[0]
alias semicolon = String(";").as_bytes()[0]
alias dash = String("-").as_bytes()[0]
alias dot = String(".").as_bytes()[0]

alias amount_lines = 1_000_000_000
alias byte_chunk_size = 2 * 1024 * 1024  # TODO: can this be autotuned or setup according to CPU cache size?
alias max_line_len = 32
alias min_line_len = 6
alias iterations = amount_lines * max_line_len // byte_chunk_size
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
