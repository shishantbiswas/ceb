# ab -n 10000 -c 1000 http://localhost:3000/
ab -n 100000 -c 1000 http://localhost:3000/favicon.svg
# ab -n 10000 -c 1000 http://localhost:3000/user/1337
# ab -n 10000 -c 1000 http://localhost:3000/api/proxy


# time labels |   CEB  v0.1.1  |   CEB  v0.1.1 no logger opt 05  |   Hono no logger (Node)  |     Hono no logger (Node)     
# real        |    0m7.950s    |              0m5.229s           |         0m5.272s         |          0m7.422s                      
# user        |    0m0.386s    |              0m0.286s           |         0m0.308s         |          0m0.408s                       
# sys         |    0m4.119s    |              0m2.873s           |         0m2.846s         |          0m4.031s                       

# ab -n 100000 -c 1000 http://localhost:3000/heyo

# siege -c 200 -r 50 http://localhost:8080/
# wrk -t8 -c200 -d30s http://localhost:8080/

