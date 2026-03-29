# ClawUI Makefile
# Build and install ClawUI

PACKAGE = clawui
VERSION = 1.0.0
RELEASE = 1

PREFIX ?= /usr
DESTDIR ?=
PKGDIR ?= /tmp/clawui-pkg

.PHONY: all install package clean

all:
	@echo "ClawUI $(VERSION)"
	@echo "Run 'make install' to install"
	@echo "Run 'make package' to create APK package"

install:
	@echo "Installing ClawUI..."
	mkdir -p $(DESTDIR)$(PREFIX)/share/clawui/www
	mkdir -p $(DESTDIR)$(PREFIX)/share/clawui/api
	mkdir -p $(DESTDIR)$(PREFIX)/sbin
	mkdir -p $(DESTDIR)/etc/clawui
	mkdir -p $(DESTDIR)/etc/init.d
	
	# Copy web files
	cp -r rootfs/usr/share/clawui/www/* $(DESTDIR)$(PREFIX)/share/clawui/www/
	
	# Copy API scripts
	cp -r rootfs/usr/share/clawui/api/* $(DESTDIR)$(PREFIX)/share/clawui/api/
	
	# Copy executables
	cp rootfs/usr/sbin/clawui $(DESTDIR)$(PREFIX)/sbin/
	chmod +x $(DESTDIR)$(PREFIX)/sbin/clawui
	
	# Copy config
	cp rootfs/etc/clawui/* $(DESTDIR)/etc/clawui/ 2>/dev/null || true
	cp rootfs/etc/init.d/clawui $(DESTDIR)/etc/init.d/
	chmod +x $(DESTDIR)/etc/init.d/clawui
	
	@echo "Done!"

package:
	@echo "Creating APK package..."
	mkdir -p $(PKGDIR)
	$(MAKE) install DESTDIR=$(PKGDIR)
	
	# Create APK package
	cd $(PKGDIR) && \
	tar -czf ../clawui-$(VERSION)-$(RELEASE).apk.tar.gz .
	
	@echo "Package created: clawui-$(VERSION)-$(RELEASE).apk.tar.gz"

clean:
	rm -rf $(PKGDIR)
	rm -f *.apk.tar.gz

test:
	@echo "Running tests..."
	@for script in rootfs/usr/share/clawui/api/*.sh; do \
		echo "Testing $$script..."; \
		bash -n $$script && echo "  OK" || echo "  FAILED"; \
	done