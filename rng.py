from collections import Counter

x = 1

def xorshift():
    global x
    x ^= x << 7
    x ^= x >> 9
    x ^= x << 8
    return x & 7

# check the distribution
M = 100000
polls = []

for _ in range(M):
    polls.append(xorshift())

c = Counter(polls)
for item, count in c.items():
    print(item, "-", count/M)