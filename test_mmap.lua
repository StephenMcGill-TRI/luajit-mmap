#!/usr/bin/env luajit

local ffi = require'ffi'
local mmap = require'mmap'

ffi.cdef [[
typedef struct __IO_FILE FILE;
size_t fwrite
  (const void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream);
size_t fread
  (void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream);
typedef struct timeval {
	long tv_sec;
	int32_t tv_usec;
} timeval;
int gettimeofday(struct timeval *restrict tp, void *restrict tzp);
]]

local shm_location = '/test0.txt'

local str1 = 'Hello world'

local ptr, sz = mmap.shm_open(shm_location, 1024)
if ptr then
  print("SHM OK", shm_location)
  -- read contents
  local buf = ffi.new('char[?]', 1024)
  ffi.copy(buf, ptr, sz)
  print("Current contents:", ffi.string(buf))
  ffi.copy(ptr, str1, sz)
  mmap.close(ptr, sz)
  
  --mmap.shm_unlink(shm_location)
else
  print("Error", sz, shm_location)
end

local f = io.open("/tmp/test1.txt", 'w')
print("Writing:", str1)
f:write(str1)
f:close()

local ptr, sz = mmap.open("/tmp/test1.txt")
local str2
if ptr then
  str2 = ffi.string(ptr, sz)
  print("Str2", str2)
  mmap.close(ptr, sz)
end
if str1~=str2 then
  print("String mismatch in mmap")
else
  print("String match OK")
end
