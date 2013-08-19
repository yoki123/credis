from gevent.event import AsyncResult

cdef class Pool:
    '''
    simple pool, used for gevent, there is not true concurrency.
    '''
    cdef public list _pool
    cdef public object ctor
    cdef public tuple args

    cdef public int max_count
    cdef public int alloc_count
    cdef public int used_count

    cdef list _waiters

    def __cinit__(self, max_count, ctor, *args):
        self.ctor = ctor
        self.args = args

        self.max_count = max_count
        self.alloc_count = 0
        self.used_count = 0

        self._pool = []
        self._waiters = []

    def acquire(self):
        try:
            res = self._pool.pop()
        except IndexError:
            if self.alloc_count >= self.max_count:
                evt = AsyncResult()
                self._waiters.append(evt)
                return evt.get()

            # allocate new resource
            res = self.ctor(*self.args)
            self.alloc_count += 1
            self.used_count += 1
        else:
            self.used_count += 1
        assert self.alloc_count - self.used_count == len(self._pool), 'impossible[1]'
        assert self.used_count <= self.alloc_count, 'impossible[2]'
        return res

    def release(self, item):
        if len(self._waiters) > 0:
            self._waiters.pop().set(item)
        else:
            self.used_count -= 1
            self._pool.append(item)
        assert self.used_count >= 0, 'impossible[3]'