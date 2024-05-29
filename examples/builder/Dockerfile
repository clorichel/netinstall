FROM ammo74/netinstall 

ENV ARCH=tile
ENV PKGS=calea 
ENV CHANNEL=testing
ENV OPTS="-xxxx -b -r"
ENV IFACE=teth0

# OPTIONAL: VER will override CHANNEL
# ENV VER = 7.14.3
# ENV VER_NETINSTALL = 7.14.3
# ENV CLIENTIP = 172.17.0.101

# NOTE: For custom package, like branding, place file next to Dockerfile and copy:
# ENV PKGS_CUSTOM = "mybranding.npk"
# COPY mybranding.npk .


RUN make download 

