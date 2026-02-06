PREFIX ?= /usr/local

.PHONY: install uninstall

install:
	@echo "Installing video-fade to $(PREFIX)/bin..."
	@mkdir -p $(PREFIX)/bin
	@cp video_fade.sh $(PREFIX)/bin/video-fade
	@chmod +x $(PREFIX)/bin/video-fade
	@echo "Done! You can now use 'video-fade' from anywhere."

uninstall:
	@echo "Removing video-fade from $(PREFIX)/bin..."
	@rm -f $(PREFIX)/bin/video-fade
	@echo "Done!"
