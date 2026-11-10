kiem tra
```
sudo lvs
sudo vgs
```
extend
```
sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
```
luw
```
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```