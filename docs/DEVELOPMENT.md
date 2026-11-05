# Phát triển và thử nghiệm

## Yêu cầu

Không cần build gì: script là QML/JS. Chỉ cần các gói đã có sẵn trong Kubuntu:
`kwin-wayland`, `kpackagetool6` (gói `libkf6package-bin` hoặc tương đương), `qdbus6` (`qt6-tools-dev-tools`
hoặc `qdbus-qt6`), `kwriteconfig6` (`libkf6config-bin`), và `spectacle` nếu muốn chụp màn hình trong KWin lồng.

## Thử trong KWin lồng (khuyến nghị)

```bash
tools/nested.sh                  # mở KWin lồng 1600x900 (WIDTH/HEIGHT/SCALE để đổi), cài script vào đó
tools/nested-run.sh kate &       # mở app trong KWin lồng (xterm & để thử cửa sổ XWayland)
tools/reload.sh --nested         # cài lại code đang sửa: khởi động lại KWin lồng (mở lại app)
tools/logs.sh --nested           # log của script (Debug=true được bật sẵn trong KWin lồng)
tools/nested.sh stop             # tắt KWin lồng
```

KWin lồng có D-Bus, thư mục config, data và cache riêng trong `.nested/`, nên không đụng tới phiên đang
dùng. Lệnh `stop` chỉ kill tiến trình `kwin_wayland` có `--socket wayland-unitedsetsx`.

Gọi phím tắt của script trong KWin lồng mà không cần bàn phím:

```bash
tools/nested-run.sh qdbus6 org.kde.kglobalaccel /component/kwin \
    org.kde.kglobalaccel.Component.invokeShortcut "UnitedSetsX Group With Window Below"
```

(Tên khác: `UnitedSetsX Next Tab`, `UnitedSetsX Previous Tab`, `UnitedSetsX Release Tab`.)

Chụp màn hình KWin lồng: `tools/nested-run.sh spectacle -b -n -f -o /đường/dẫn/ảnh.png`

## Cài vào phiên thật

```bash
tools/install.sh        # cài hoặc nâng cấp, bật script
tools/uninstall.sh      # trả lại mọi cửa sổ, gỡ script và effect
tools/logs.sh           # journalctl --user -u plasma-kwin_wayland.service, lọc dòng của script
```

Lưu ý: KWin cache file QML của script, nên sau khi nâng cấp code trong phiên thật cần đăng xuất / đăng
nhập lại để code mới có hiệu lực. Bật log chi tiết:
`kwriteconfig6 --file kwinrc --group Script-unitedsetsx --key Debug true` rồi
`qdbus6 org.kde.KWin /KWin reconfigure`.

## Lệnh D-Bus hữu ích

```bash
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded unitedsetsx
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript unitedsetsx   # dừng (trả lại cửa sổ)
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start                      # nạp các script đang bật
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded unitedsetsx_mod_ctrl
```

## Bài học

- Script declarative không có `workspace.windowList()`; dùng `Workspace.windows`.
- Cửa sổ nội bộ của KWin (thanh tab) có `managed = true`, `pid = -1`, `resourceClass` rỗng.
- Binding QML không được đọc `Workspace.stackingOrder` (không bindable, KWin in cảnh báo mỗi lần).
- Tiến trình con của KWin được chạy qua systemd: PID cha của nó là `systemd --user`, **không phải**
  KWin. Đừng bao giờ kill theo `$PPID` (lỗi này từng làm sập cả phiên).
