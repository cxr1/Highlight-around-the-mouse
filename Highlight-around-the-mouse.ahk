; gdi+ ahk tutorial 1 written by tic (Tariq Porter)
; Requires Gdip.ahk either in your Lib folder as standard library or using #Include
;
; Tutorial to draw a single ellipse and rectangle to the screen

#SingleInstance, Force
#NoEnv
SetBatchLines, -1

; Uncomment if Gdip.ahk is not in your standard library
; 加载 GDI+ 库。
#Include, Gdip.ahk

; Start gdi+
; 初始化 GDI+ 。要用到 GDI+ 的各种功能，必须先初始化！
; 这里加个判断，检测一下初始化是否成功，失败就弹窗告知，并退出程序。
If !pToken := Gdip_Startup()
{
	MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
	ExitApp
}
; 设置程序结束时，要跳转到名为 GdipExit 的标签去运行。通常在那里执行释放资源以及关闭 GDI+ 等收尾操作。
OnExit, GdipExit

; Create a layered window (+E0x80000 : must be used for UpdateLayeredWindow to work!) that is always on top (+AlwaysOnTop), has no taskbar entry or caption
; 创建一个分层（又叫异型）的界面， +E0x80000 选项是必须的，不然等会图片贴不到这上面来。
Gui, 1: -Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs  -Border 

; Show the window
; 显示界面。
; 注意，这里虽然叫显示界面，但因为使用了 +E0x80000 选项，所以此刻看起来还是什么都没有的，需要等会用 GDI+ 把图案画出来才能真正显示。
Gui, 1: Show, NA
WinSet, ExStyle, +0x20
; Get a handle to this window we have created in order to update it later
; 获取界面句柄。实际上也可以通过创建界面时使用 +Hwnd 选项获得句柄，两种方法都一样的。
hwnd1 := WinExist()

; Set the width and height we want as our drawing area, to draw everything in. This will be the dimensions of our bitmap
; 创建宽和高两个变量，下一句会用到。
Width :=100, Height := 100

; Create a gdi bitmap with width and height of what we are going to draw into it. This is the entire drawing area for everything
; 创建一个与设备无关的位图。什么叫与设备无关呢？
; 比如你创建一个和屏幕有关的位图，同时你的屏幕是256彩色显示的，这个位图就只能是256彩色。
; 又比如你创建一个和黑白打印机有关的位图，这个位图就只能是黑白灰色的。
; 设备相关位图 DDB(Device-Dependent-Bitmap)
; DDB 不具有自己的调色板信息，它的颜色模式必须与输出设备相一致。
; 如：在256色以下的位图中存储的像素值是系统调色板的索引，其颜色依赖于系统调色板。
; 由于 DDB 高度依赖输出设备，所以 DDB 只能存在于内存中，它要么在视频内存中，要么在系统内存中。
; 设备无关位图 DIB(Device-Independent-Bitmap)
; DIB 具有自己的调色板信息，它可以不依赖系统的调色板。
; 由于它不依赖于设备，所以通常用它来保存文件，如 .bmp 格式的文件就是 DIB 。
; 使用指定的宽高创建这个位图，之后不管你是画画也好，贴图也罢，就这么大地方给你用了。
hbm := CreateDIBSection(Width, Height)

; Get a device context compatible with the screen
; 创建一个设备环境，也就是 DC 。那什么叫 DC 呢？
; 首先，当我们想要屏幕显示出一个红色圆形图案的话，正常逻辑是直接告诉显卡，给我在 XX 坐标，显示一个 XX 大小， XX 颜色的圆出来。
; 但 Windows 不允许程序员直接访问硬件。所以当我们想要对屏幕进行操作，就得通过 Windows 提供的渠道才行。这个渠道，就是 DC 。
; 屏幕上的每一个窗口都对应一个 DC ，可以把 DC 想象成一个视频缓冲区，对这个缓冲区进行操作，会表现在这个缓冲区对应的屏幕窗口上。
; 在窗口的 DC 之外，可以建立自己的 DC ，就是说它不对应窗口，这个方法就是 CreateCompatibleDC() 。
; 这个 DC 就是一个内存缓冲区，通过这个 DC 你可以把和它兼容的窗口 DC 保存到这个 DC 中，就是说你可以通过它在不同的 DC 之间拷贝数据。
; 例如，你先在这个 DC 中建立好数据，然后再拷贝到目标窗口的 DC 中，就完成了对目标窗口的刷新。
; 最后，之所以叫设备环境，不叫屏幕环境，是因为对其它设备，比如打印机的操作，也是通过它来完成的。
; 额外的扩展，CreateCompatibleDC() 函数，创建的DC，又叫内存DC，也叫兼容DC。
; 我们在绘制界面的时候，常常会听到说什么“双缓冲技术”避免闪烁，实际上就是先把内容在内存DC中画好，再一次性拷贝到目标DC里。
; 而普通的画法，就是直接在目标DC中边显示边画，所以就会闪烁。
hdc := CreateCompatibleDC()

; Select the bitmap into the device context
; 学名上，这里叫做 “把 GDI 对象选入 DC 里” 。
; 为了方便理解呢，可以认为是 “把位图扔 DC 里”。
; 因为 DC 需要具体的东西才能显示嘛，所以得把东西扔里面去。
; 注意这个函数的特点，它把 hbm 更新了，同时它返回的值是旧的 hbm ！
; 这里旧的 hbm 得存着，未来释放资源的时候需要用到。
obm := SelectObject(hdc, hbm)

; Get a pointer to the graphics of the bitmap, for use with drawing functions
; G 表示的是一张画布，之后不管我们贴图也好，画画也好，都是画到这上面。
; 如果你是刚开始接触 GDI+ ，可能还没有完全弄懂这些东西的意思，所以这里总结一下基本流程。
; 初始化 GDI+ ----> 创建位图 ----> 创建 DC ----> 把位图扔 DC 里 ----> 创建画布
; 以上就是一个开始的定式，暂时不懂也没关系，记住就行了。
G := Gdip_GraphicsFromHDC(hdc)

; Set the smoothing mode to antialias = 4 to make shapes appear smother (only used for vector drawing and filling)
; 设置画布的平滑选项，也就是抗锯齿选项，这里我们设为4。
; 注意，这个抗锯齿设置只有在你准备画画和填充的时候才有用，当你比如想贴图的时候，是无效的。
; 作业：自己改动这个选项，查看不同选项的效果。
; SmoothingModeInvalid     = -1 {一个无效模式}
; SmoothingModeDefault     = 0  {不消除锯齿}
; SmoothingModeHighSpeed   = 1  {高速度、低质量}
; SmoothingModeHighQuality = 2  {高质量、低速度}
; SmoothingModeNone        = 3  {不消除锯齿}
; SmoothingModeAntiAlias   = 4  {消除锯齿}
Gdip_SetSmoothingMode(G, 4)

; Create a fully opaque red brush (ARGB = Transparency, red, green, blue) to draw a circle
; 创建一支实心的刷子，并给它设置一个透明度及颜色。
; 注意， GDI+ 里的颜色，很多都是 ARGB 格式的。
; A = 透明度 （0 = 完全透明 255 = 不透明）
; R = 红色
; G = 绿色
; B = 蓝色
; 所以，这里 0xffff0000 的意思就是 （0x ff ff 00 00） 即 （不透明 红色255 绿色0 蓝色0）。
; 所以，就表示这是一支不透明的，纯红色的刷子。
pBrush := Gdip_BrushCreateSolid(0x80808000)

; Fill the graphics of the bitmap with an ellipse using the brush created
; Filling from coordinates (100,50) an ellipse of 200x300
; 用刚那支红刷子在画布上画一个椭圆。
; 整个函数的参数分别是 Gdip_FillEllipse(画布, 刷子, x, y, 椭圆宽, 椭圆高)
Gdip_FillEllipse(G, pBrush, 0, 0, 100, 100)

; Delete the brush as it is no longer needed and wastes memory
; 因为之后我们不再使用这支红刷子了，所以删除掉，释放资源。
Gdip_DeleteBrush(pBrush)

; Create a slightly transparent (66) blue brush (ARGB = Transparency, red, green, blue) to draw a rectangle
; 创建一支半透明（透明度 0x66）的，蓝色的刷子。
pBrush := Gdip_BrushCreateSolid(0x660000ff)

; Fill the graphics of the bitmap with a rectangle using the brush created
; Filling from coordinates (250,80) a rectangle of 300x200
; 用刚那支蓝刷子在画布上画一个矩形。
; 整个函数的参数分别是 Gdip_FillRectangle(画布, 刷子, x, y, 矩形宽, 矩形高)
;Gdip_FillRectangle(G, pBrush, 250, 80, 300, 200)

; Delete the brush as it is no longer needed and wastes memory
; 同样删除刷子。
Gdip_DeleteBrush(pBrush)

; Update the specified window we have created (hwnd1) with a handle to our bitmap (hdc), specifying the x,y,w,h we want it positioned on our screen
; So this will position our gui at (0,0) with the Width and Height specified earlier
; 将 DC 上的内容显示在窗口上。此时，你刚画的两个图案，就真正显示出来了。


loop{
	CoordMode, Mouse, Screen 
	MouseGetPos, OutputVarX, OutputVarY
	UpdateLayeredWindow(hwnd1, hdc, OutputVarX-50, OutputVarY-50, Width, Height)
	Sleep, 10
}


; The graphics may now be deleted
; 到此整个绘画工作就结束了，因此下面开始释放资源。
; 这里依然总结一下，结束的流程跟开始的流程基本一致，也是定式。
; 删除画布 ----> 还原位图 ----> 删除 DC ----> 删除位图 ----> 关闭 GDI+
; 删除画布。
Gdip_DeleteGraphics(G)

; Select the object back into the hdc
; 还原位图。
SelectObject(hdc, obm)

; Also the device context related to the bitmap may be deleted
; 删除 DC 。
DeleteDC(hdc)

; Now the bitmap may be deleted
; 删除位图。
DeleteObject(hbm)

Return

;#######################################################################
GuiClose:
GuiEscape:
GdipExit:
	; gdi+ may now be shutdown on exiting the program
	; 别忘了，我们最开始用 Gdip_Startup() 启动了，这里对应要用 Gdip_Shutdown() 关闭它。
	Gdip_Shutdown(pToken)
	ExitApp
Return
