# so i can call make from enosi's root dir to rebuild lake
all:
	cd iro && ${MAKE} -j
	cd lake && ${MAKE} -j

luajit:
	-mkdir luajit/lib
	-mkdir luajit/include
	cd luajit/src && \
	${MAKE} clean && \
	${MAKE} -j 
	cp luajit/src/src/libluajit.a luajit/lib
	cp luajit/src/src/lua.h     \
		 luajit/src/src/lualib.h  \
		 luajit/src/src/lauxlib.h \
		 luajit/src/src/luajit.h  \
		 luajit/src/src/luaconf.h \
		 luajit/include

clean:
	cd iro && ${MAKE} clean
	cd lake && ${MAKE} clean

.PHONY: all luajit
