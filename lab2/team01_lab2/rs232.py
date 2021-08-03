#!/usr/bin/env python
from serial import Serial, EIGHTBITS, PARITY_NONE, STOPBITS_ONE
from sys import argv

assert len(argv) == 2
s = Serial(
    port=argv[1],
    baudrate=115200,
    bytesize=EIGHTBITS,
    parity=PARITY_NONE,
    stopbits=STOPBITS_ONE,
    xonxoff=False,
    rtscts=False
)

fp_key = open('key.bin', 'rb')
fp_enc = open('enc1.bin', 'rb')
fp_dec = open('dec1.bin', 'wb')
fp_end = open('end.bin', 'rb')
assert fp_key and fp_enc and fp_dec

key = fp_key.read(64)
enc = fp_enc.read()
change = fp_end.read()
assert len(enc) % 32 == 0

s.write(key)
# s.write(key[0:32])
# dec = s.read(31)

for i in range(0, len(enc), 32):
    s.write(enc[i:i+32])
    dec = s.read(31)
    fp_dec.write(dec)

s.write(change)

fp_key.close()
fp_enc.close()
fp_dec.close()
fp_end.close()
