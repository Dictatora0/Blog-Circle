#!/usr/bin/expect -f

set timeout 30

spawn ssh root@10.211.55.11

expect {
    "password:" {
        send "747599qw@\r"
        exp_continue
    }
    "# " {
        send "docker exec blogcircle-frontend cat /var/log/nginx/error.log | tail -30\r"
        expect "# "
        
        send "echo '=== Nginx Config ==='\r"
        expect "# "
        
        send "docker exec blogcircle-frontend cat /etc/nginx/conf.d/default.conf\r"
        expect "# "
        
        send "echo '=== Test from container ==='\r"
        expect "# "
        
        send "docker exec blogcircle-frontend wget -O- http://localhost:8081/api/auth/login --post-data='{\"username\":\"apitest\",\"password\":\"test123\"}' --header='Content-Type: application/json' 2>&1\r"
        expect "# "
        
        send "exit\r"
    }
}

expect eof
