-- AUTHOR: Stephen McGill, 2017
-- Description: Open files using memory mapping

local lib = {}

------------------
-- Dependencies
local ffi = require'ffi'
local bit = require'bit'
local C = ffi.C
------------------

-- /usr/include/x86_64-linux-gnu/bits/fcntl-linux.h
local O_RDONLY = 0x00
-- local O_WRONLY = 0x01
local O_RDWR = 0x02
local O_CREAT = 0x40
if ffi.os=="OSX" then O_CREAT = 0x0200 end
local O_CREATE_RW = bit.bor(O_CREAT, O_RDWR)
--
ffi.cdef[[
int open(const char *pathname, int flags);
int close(int fd);
int ftruncate(int fd, long long length);
long long lseek(int fildes, long long offset, int whence);
]]

-- /usr/include/x86_64-linux-gnu/bits/mman-linux.h
local PROT_READ = 0x01
local PROT_WRITE = 0x02
-- Custom:
local PROT_READWRITE = bit.bor(PROT_READ, PROT_WRITE)
--
local MAP_SHARED = 0x01
local MAP_PRIVATE = 0x02
--
ffi.cdef[[
void *mmap(void *addr, size_t length, int prot, int flags, int fd, long int offset);
int munmap(void *addr, size_t length);
]]

-- Mode: 0600
local S_IRWUSR = 384
local has_rt, rt = pcall(ffi.load, 'rt')
ffi.cdef[[
int shm_open(const char *name, int oflag, unsigned short mode);
int shm_unlink(const char *name);
]]

ffi.cdef[[
void perror(const char *s);
]]

-- This is read-only mmap access
function lib.open(filename)
  -- Open and grab the size
  local f, status = io.open(filename)
  if not f then return false, status end
  local sz = f:seek'end'
  f:close()
  -- Open as file descriptor
  local fd = C.open(filename, O_RDONLY)
  -- TODO: Add option for shared/private mapping
  local ptr = ffi.cast('uint8_t*',
    C.mmap(nil, sz, PROT_READ, MAP_PRIVATE, fd, 0))
  -- Close the descriptor
  C.close(fd)
  if ptr==nil then return false, "Bad mmap" end
  return ptr, sz
end

function lib.close(ptr, sz, fd)
  return C.munmap(ptr, sz) == 0
  -- if fd then C.close(fd) end
end

local function shm_unlink(filename)
  local ret = has_rt and rt.shm_unlink(filename) or C.shm_unlink(filename)
  if ret~=0 then
    return false
  end
  return true
end
lib.shm_unlink = shm_unlink

-- Create this file with a certain size
-- shm_open is a library function on Linux
-- shm_open is a syscall on macOS
function lib.shm_open(filename, sz)
  local fd = has_rt and
    rt.shm_open(filename, O_CREATE_RW, S_IRWUSR) or 
    C.shm_open(filename, O_CREATE_RW, S_IRWUSR)
  if fd < 0 then
    return false, "Failed to open shared memory"
  end
  if type(sz) ~= 'number' then
    if ffi.os ~= 'Linux' then
      C.close(fd)
      -- shm_unlink(filename)
      return false, "Please provide a size for the shared memory segment"
    end
    sz = C.lseek(fd, 0, 2)
    if sz == -1 then
      C.perror("lseek")
      C.close(fd)
      return false, "Bad seek to end"
    end
    local start = C.lseek(fd, 0, 0)
    if start ~= 0 then
      C.perror("lseek")
      C.close(fd)
      return false, "Bad seek to start"
    end
  end
  --
  local ret = C.ftruncate(fd, sz)
  if ret ~= 0 then
    C.perror("ftruncate")
    C.close(fd)
    return false, "Bad file truncate"
  end
  --
  local ptr = C.mmap(nil, sz, PROT_READWRITE, MAP_SHARED, fd, 0)
  ptr = ffi.cast('uint8_t*', ptr)
  C.close(fd)
  --
  if ptr == nil then
    return false, "Bad mmap"
  end
  --
  return ptr, sz
end

-- torch7 storage access
if torch then
  lib.storage = function (ptr, sz)
    local ptr0 = tonumber(ffi.cast('intptr_t', ffi.cast('void *', ptr)))
    return torch.ByteStorage(tonumber(sz), ptr0)
  end
end

return lib