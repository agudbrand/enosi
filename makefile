# so i can call make from enosi's root dir to rebuild lake
all:
	cd lake && ${MAKE} -j8

.PHONY: all
