ab -n 10000 -c 1000 http://localhost:3000/
ab -n 10000 -c 1000 http://localhost:3000/favicon.png
ab -n 10000 -c 1000 http://localhost:3000/user/1337
ab -n 10000 -c 1000 http://localhost:3000/api/proxy

# siege -c 200 -r 50 http://localhost:8080/
# wrk -t8 -c200 -d30s http://localhost:8080/

