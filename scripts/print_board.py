def print_board(n, bb):
    s = bin(bb)[2:]
    s2 = "0" * (n * n - len(s)) + s
    for i in range(n):
        print(s2[n*i:n*i+n])
