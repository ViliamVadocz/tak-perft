from random import randint

for _ in range(10):    
    d = dict()
    total_collisions = 0

    for i in range(1_000_000):
        r = randint(1, 1 << 20)
        hits = d.setdefault(r, 0)
        if hits > 0: total_collisions += 1
        d[r] = hits + 1


    distr = [0] * 16
    most_hits = 0

    for hits in d.values():
        distr[hits] += 1
        if hits > most_hits: most_hits = hits

    print(f"{total_collisions = }")
    print(f"{most_hits = }")
    print(f"{distr = }")
    print("===")
