function prime (x)
if x <= 1 then return false end
for n = 2, x - 1 do if (x % n) == 0 then return false end end
return true
end
for x = 0, 1000 do if prime(x) then io.write(x .. "\9") end end