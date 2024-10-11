.PHONY: init update server

init: 
    git clone --recurse-submodules https://github.com/arloor/arloor.github.io
update:
	git submodule update --init --recursive
server:
	hugo server -b http://127.0.0.1:1313 -p 5505 --disableFastRender