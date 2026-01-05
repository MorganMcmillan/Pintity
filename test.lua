#include parens8/parens8.lua

tbl = {}

parens8[[(set tbl.% "percent")]]

print(tbl["%"])