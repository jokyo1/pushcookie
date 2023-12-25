FROM debian:sid
RUN chown root:shadow /etc/shadow; chmod 640 /etc/shadow;
RUN [ -r /sbin/unix_chkpwd ] && chmod 2755 /sbin/unix_chkpwd || echo "/sbin/unix_chkpwd skipped"
RUN useradd -d /home/user -s /bin/bash -m -u 1000 user
RUN chown user -R /home/user; echo "cd ~" > /home/user/.bashrc;
RUN --mount=type=secret,id=VNC_PASSWORD,mode=0444,required=true \
    echo 'user:$(cat /run/secrets/VNC_PASSWORD)' | chpasswd
RUN pwconv
#RUN apt-add-repository "deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib"
#RUN wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
RUN apt update
RUN apt install -y vim bash xfce4-terminal mate-desktop-environment-extras \
    aqemu sudo curl wget aria2 qemu-system-x86 htop chromium screen \
    tigervnc-standalone-server python3-pip python3-websockify \
    python3 git fuse libfuse2 xdotool cron
#    virtualbox
RUN apt remove -y lxlock
RUN apt remove -y light-locker xscreensaver-data xscreensaver
RUN [ -r /etc/xdg/lxsession/LXDE/autostart ] && sed -i '/@xscreensaver -no-splash/d' /etc/xdg/lxsession/LXDE/autostart || echo "/etc/xdg/lxsession/LXDE/autostart skipped"
RUN (gsettings set org.gnome.desktop.session idle-delay 0; gsettings set org.gnome.desktop.screensaver lock-enabled false;) || exit 0;
# RUN modprobe fuse
# RUN usermod -a -G fuse user
# RUN chmod -R o+r / 2>/dev/null; exit 0; 

#创建一个普通用户，并将其添加到`cron`组中
RUN usermod -a -G crontab user
#编辑`/etc/cron.allow`文件，将普通用户的用户名添加到其中
RUN echo "user" >> /etc/cron.allow
#编辑`/etc/pam.d/cron`文件，将`session required pam_loginuid.so`这一行注释掉
RUN sed -i '/pam_loginuid.so/s/^/#/' /etc/pam.d/cron
# 在Dockerfile中启动`cron`服务
#CMD cron && tail -f /var/log/cron.log
# 创建一个启动脚本
RUN echo "#!/bin/bash" > /start.sh && \
    echo "service cron start" >> /start.sh && \
    echo "exec \"\$@\"" >> /start.sh && \
    chmod +x /start.sh

# 使用启动脚本作为入口点
ENTRYPOINT ["/start.sh"]



RUN hostname hf-server || echo 'failed to set hostname'
RUN git clone https://github.com/novnc/noVNC.git noVNC
RUN mkdir -p /home/user/.vnc
RUN chmod -R 777 /home/user/.vnc /tmp
RUN --mount=type=secret,id=VNC_PASSWORD,mode=0444,required=true \
    cat /run/secrets/VNC_PASSWORD | vncpasswd -f > /home/user/.vnc/passwd
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH
    
# 假设pushcookie文件夹在当前目录下
RUN mkdir -p /home/user/Desktop/myshell
ADD myshell/ /home/user/Desktop/myshell/
# 使用RUN指令执行chmod命令给予*.sh文件可执行权限
RUN chmod 777 /home/user/Desktop/myshell/*.sh 
#定时25分钟执行点击任务
#RUN cat /home/user/Desktop/myshell/task.txt | crontab -u user -
RUN crontab -u user /home/user/Desktop/myshell/task.txt


RUN tar -xzf /home/user/Desktop/myshell/chromeset.tar.gz -C /tmp/ 
#RUN rm -rf /home/user/.config/chromium
#RUN mkdir -p /home/user/.config/chromium
# 切换到 user 用户
USER user
# 复制 /tmp/.config/chromium 目录到 /home/user/.config/ 目录，保留文件属性和链接
RUN cp -a /tmp/home/user/.config/chromium /home/user/.config/
#RUN cp -a  /tmp/.config/chromium /home/user/.config/chromium/ && chown -R user:user /home/user/.config/chromium

    
ARG VNC_RESOLUTION
CMD vncserver -SecurityTypes VncAuth -rfbauth /home/user/.vnc/passwd -geometry $VNC_RESOLUTION && ./noVNC/utils/novnc_proxy --vnc localhost:5901 --listen 0.0.0.0:7860
# 切换到 user 用户
USER user
# 复制 /tmp/.config/chromium 目录到 /home/user/.config/ 目录，保留文件属性和链接
RUN cp -a /tmp/home/user/.config/chromium /home/user/.config/
#RUN cp -a  /tmp/.config/chromium /home/user/.config/chromium/ && chown -R user:user /home/user/.config/chromium
#CMD /home/user/Desktop/myshell/clickbing.sh