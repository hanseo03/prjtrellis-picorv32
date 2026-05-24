#!/usr/bin/env python3
"""
makehex.py  —  바이너리 파일을 Verilog $readmemh 형식 HEX로 변환

사용법:
  python3 makehex.py <input.bin> <words> > firmware.hex

  <words> : 출력할 32비트 워드 수 (= MEM_WORDS, attosoc.v 의 8192)
"""

import sys

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <binary_file> <num_words>", file=sys.stderr)
        sys.exit(1)

    bin_file  = sys.argv[1]
    num_words = int(sys.argv[2])

    with open(bin_file, "rb") as f:
        data = f.read()

    # 4바이트(32비트) 단위로 읽어서 출력
    for i in range(num_words):
        offset = i * 4
        if offset + 4 <= len(data):
            word = (data[offset]
                  | data[offset+1] << 8
                  | data[offset+2] << 16
                  | data[offset+3] << 24)
        else:
            word = 0  # 바이너리보다 큰 영역은 0으로 채움
        print(f"{word:08X}")

if __name__ == "__main__":
    main()
