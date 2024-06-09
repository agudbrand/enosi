# so i can call make from enosi's root dir to rebuild lake
all:
	cd lake && ${MAKE} -j8

luajit:
	mkdir luajit/lib
	mkdir luajit/include
	cd luajit/src && \
	${MAKE} clean && \
	${MAKE} -j 
	cp luajit/src/src/libluajit.a luajit/lib
	cp luajit/src/src/{lua.h,lualib.h,lauxlib.h} luajit/include

.PHONY: all luajit
