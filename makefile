# so i can call make from enosi's root dir to rebuild lake
all:
	cd lake && ${MAKE} -j8

luajit:
	cd LuaJIT && \
	${MAKE} clean && \
	${MAKE} -j8 
	cp LuaJIT/src/libluajit.a lake/lib
	cp LuaJIT/src/{lua.h,lualib.h,lauxlib.h} lake/include

.PHONY: all
