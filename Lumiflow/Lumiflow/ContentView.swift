//
//  ContentView.swift
//  Lumiflow
//
//  Created by Claude on 2024.
//

import SwiftUI
import AVFoundation
import Photos
import MediaPlayer

struct ColorOption: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
}

// Toast通知视图
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.7))
            .cornerRadius(10)
    }
}

// 重新设计的相机预览视图，确保正确显示实时影像
struct CameraPreview: UIViewRepresentable {
    class VideoPreviewView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer
        
        init(session: AVCaptureSession) {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            super.init(frame: .zero)
            
            // 确保预览图层正确配置
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.opacity = 1
            
            // 添加预览图层到视图
            layer.addSublayer(previewLayer)
            
            // 确保视图背景是透明的
            backgroundColor = .clear
            
            // 打印日志
            print("相机预览视图已初始化")
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
            
            // 确保视频方向正确
            if let connection = previewLayer.connection {
                let orientation = UIDevice.current.orientation
                
                if connection.isVideoOrientationSupported {
                    switch orientation {
                    case .portrait:
                        connection.videoOrientation = .portrait
                    case .landscapeLeft:
                        connection.videoOrientation = .landscapeRight
                    case .landscapeRight:
                        connection.videoOrientation = .landscapeLeft
                    case .portraitUpsideDown:
                        connection.videoOrientation = .portraitUpsideDown
                    default:
                        connection.videoOrientation = .portrait
                    }
                }
            }
            
            print("相机预览视图布局已更新: \(bounds.size)")
        }
    }
    
    let captureSession: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView(session: captureSession)
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                print("在updateUIView中启动相机会话")
            }
        }
    }
}

class CameraViewModel: NSObject, ObservableObject {
    @Published var isShowingCamera = false
    @Published var capturedImage: UIImage?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var cameraError: String? = nil
    
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCapturePhotoOutput?
    
    // 初始化时不自动请求权限和设置相机，等用户点击按钮时再初始化
    override init() {
        super.init()
        // 不再自动调用checkPermissionsAndSetupCamera()
    }
    
    func checkPermissionsAndSetupCamera() {
        // 检查相机权限
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // 已经有权限，可以设置相机
            self.setupCamera()
        case .notDetermined:
            // 还没决定，请求权限
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.cameraError = "camera_permission_denied".localized
                    }
                }
            }
        case .denied, .restricted:
            // 被拒绝或受限
            self.cameraError = "camera_permission_denied".localized
            return
        @unknown default:
            return
        }
    }
    
    func setupCamera() {
        print("开始设置相机")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 如果已经有一个会话在运行，先停止它
            if let existingSession = self.captureSession, existingSession.isRunning {
                existingSession.stopRunning()
            }
            
            // 创建新的捕获会话
            let session = AVCaptureSession()
            session.sessionPreset = .high
            
            // 使用前置摄像头（而不是后置摄像头）
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ?? 
                  AVCaptureDevice.default(for: .video) else {
                DispatchQueue.main.async {
                    self.cameraError = "camera_not_available".localized
                    print("没有可用的相机设备")
                }
                return
            }
            
            do {
                // 配置相机输入
                let input = try AVCaptureDeviceInput(device: camera)
                
                if session.canAddInput(input) {
                    session.addInput(input)
                } else {
                    throw NSError(domain: "无法添加相机输入", code: 0, userInfo: nil)
                }
                
                // 配置照片输出
                let output = AVCapturePhotoOutput()
                
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    self.stillImageOutput = output
                } else {
                    throw NSError(domain: "无法添加照片输出", code: 0, userInfo: nil)
                }
                
                // 保存会话并开始运行
                self.captureSession = session
                
                DispatchQueue.main.async {
                    // 启动相机会话并更新UI
                    self.startSession()
                    print("相机设置成功，准备启动会话")
                }
            } catch {
                DispatchQueue.main.async {
                    self.cameraError = "camera_setup_failed".localized
                    print("相机设置失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func startSession() {
        print("开始启动相机会话")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let session = self.captureSession else {
                print("没有可用的相机会话，无法启动")
                return
            }
            
            if !session.isRunning {
                session.startRunning()
                print("相机会话已启动")
                
                DispatchQueue.main.async {
                    self.isShowingCamera = true
                    print("相机UI已显示")
                }
            } else {
                DispatchQueue.main.async {
                    self.isShowingCamera = true
                    print("相机会话已经在运行")
                }
            }
        }
    }
    
    func stopSession() {
        print("开始停止相机会话")
        
        // 先更新UI状态，确保预览立即消失
        DispatchQueue.main.async {
            self.isShowingCamera = false
            print("相机UI已隐藏")
        }
        
        // 然后在后台线程停止会话
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let session = self.captureSession else {
                print("没有可用的相机会话，无需停止")
                return
            }
            
            if session.isRunning {
                session.stopRunning()
                print("相机会话已停止")
            } else {
                print("相机会话已经停止，无需操作")
            }
        }
    }
    
    // 添加一个帮助方法来显示相机未准备好的提示
    private func showCameraNotReadyToast() {
        self.toastMessage = "camera_not_ready".localized
        self.showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showToast = false
        }
    }
    
    func capturePhoto() {
        // 检查相机会话是否存在
        guard let captureSession = captureSession else {
            showCameraNotReadyToast()
            return
        }
        
        // 如果会话存在但未运行，尝试启动会话
        if !captureSession.isRunning {
            // 在后台线程启动相机
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                captureSession.startRunning()
                
                // 等待相机启动完成（给予一点时间让相机预热）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    
                    if captureSession.isRunning, let stillImageOutput = self.stillImageOutput {
                        // 现在相机已经运行，可以拍照
                        let settings = AVCapturePhotoSettings()
                        settings.flashMode = .off
                        print("延迟启动相机后拍照...")
                        stillImageOutput.capturePhoto(with: settings, delegate: self)
                    } else {
                        // 如果仍然无法启动，显示提示
                        self.showCameraNotReadyToast()
                    }
                }
            }
            return
        }
        
        // 检查照片输出是否存在，并且会话正在运行
        guard let stillImageOutput = stillImageOutput, captureSession.isRunning else {
            showCameraNotReadyToast()
            return
        }
        
        // 配置照片设置
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        // 捕获照片
        print("正在拍照...")
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func savePhotoToLibrary(image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: image.jpegData(compressionQuality: 0.9)!, options: nil)
                }) { success, error in
                    DispatchQueue.main.async { [weak self] in
                        if success {
                            self?.toastMessage = "photo_saved".localized
                            self?.showToast = true
                            
                            // 3秒后自动隐藏Toast
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                self?.showToast = false
                            }
                            
                            print("照片已保存到相册")
                        } else if let error = error {
                            self?.toastMessage = "photo_save_failed".localized
                            self?.showToast = true
                            
                            // 3秒后自动隐藏Toast
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                self?.showToast = false
                            }
                            
                            print("保存照片出错: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("拍照时出错: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
            if let image = self?.capturedImage {
                self?.savePhotoToLibrary(image: image)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var selectedColor: Color = .white
    @State private var brightness: Double = UIScreen.main.brightness
    @State private var originalBrightness: CGFloat = UIScreen.main.brightness
    @State private var saturation: Double = 1.0
    @State private var showColorPicker = false
    
    // 新增：记录每个颜色的理想饱和度
    @State private var colorSaturationMap: [String: Double] = [:]
    
    // 记录颜色选择前的状态，用于重置
    @State private var wasColorPickerShown = false
    
    // 相机预览框位置控制
    @State private var previewOffset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var previewScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    // 音量按钮监听
    @State private var volumeObserver: NSObjectProtocol? = nil
    
    // 重新排序和修正的颜色选项
    let colorOptions: [ColorOption] = [
        // 白色系
        ColorOption(name: "晨曦白", color: .white),
        ColorOption(name: "象牙白", color: Color(red: 0.95, green: 0.95, blue: 0.9)),
        ColorOption(name: "瓷釉白", color: Color(red: 0.95, green: 0.95, blue: 0.9)),
        ColorOption(name: "茉莉白", color: Color(red: 0.98, green: 0.98, blue: 0.92)),
        ColorOption(name: "青玉白", color: Color(red: 0.9, green: 0.97, blue: 0.98)),
        
        // 灰色系 - 修正
        ColorOption(name: "薄雾灰", color: Color(red: 0.75, green: 0.75, blue: 0.78)),
        ColorOption(name: "月影银", color: Color(red: 0.82, green: 0.82, blue: 0.88)),
        ColorOption(name: "石墨灰", color: Color(red: 0.4, green: 0.4, blue: 0.45)),
        ColorOption(name: "苍岩灰", color: Color(red: 0.55, green: 0.55, blue: 0.5)),
        ColorOption(name: "烟雨灰", color: Color(red: 0.6, green: 0.65, blue: 0.65)),
        
        // 黑色系 - 进一步修正
        ColorOption(name: "墨玉黑", color: Color(red: 0.08, green: 0.08, blue: 0.1)),
        ColorOption(name: "暗夜蓝", color: Color(red: 0.02, green: 0.02, blue: 0.08)),
        
        // 红色系
        ColorOption(name: "玫瑰粉", color: Color(red: 0.96, green: 0.76, blue: 0.76)),
        ColorOption(name: "绛紫红", color: Color(red: 0.8, green: 0.15, blue: 0.35)),
        ColorOption(name: "丝绒红", color: Color(red: 0.7, green: 0.0, blue: 0.0)),
        ColorOption(name: "赤霞红", color: Color(red: 0.85, green: 0.3, blue: 0.25)),
        ColorOption(name: "胭脂红", color: Color(red: 0.9, green: 0.25, blue: 0.25)),
        ColorOption(name: "珊瑚红", color: Color(red: 0.95, green: 0.45, blue: 0.4)),
        ColorOption(name: "火玫瑰", color: Color(red: 0.85, green: 0.3, blue: 0.35)),
        
        // 橙色系
        ColorOption(name: "琥珀橙", color: Color(red: 0.98, green: 0.63, blue: 0.25)),
        ColorOption(name: "秋叶橙", color: Color(red: 0.9, green: 0.4, blue: 0.1)),
        ColorOption(name: "珊瑚橙", color: Color(red: 0.95, green: 0.5, blue: 0.4)),
        ColorOption(name: "柿子橙", color: Color(red: 0.9, green: 0.5, blue: 0.15)),
        
        // 黄色系
        ColorOption(name: "暮光金", color: Color(red: 0.99, green: 0.85, blue: 0.65)),
        ColorOption(name: "暖阳黄", color: Color(red: 1.0, green: 0.9, blue: 0.3)),
        ColorOption(name: "金沙黄", color: Color(red: 0.9, green: 0.8, blue: 0.5)),
        ColorOption(name: "杏仁黄", color: Color(red: 0.95, green: 0.8, blue: 0.6)),
        
        // 绿色系
        ColorOption(name: "翡翠绿", color: Color(red: 0.0, green: 0.8, blue: 0.6)),
        ColorOption(name: "岚青绿", color: Color(red: 0.2, green: 0.7, blue: 0.5)),
        ColorOption(name: "松针绿", color: Color(red: 0.2, green: 0.5, blue: 0.3)),
        ColorOption(name: "薄荷绿", color: Color(red: 0.4, green: 0.8, blue: 0.7)),
        ColorOption(name: "柳叶绿", color: Color(red: 0.6, green: 0.8, blue: 0.3)),
        ColorOption(name: "春芽绿", color: Color(red: 0.55, green: 0.75, blue: 0.4)),
        
        // 蓝色系
        ColorOption(name: "静谧蓝", color: Color(red: 0.53, green: 0.81, blue: 0.92)),
        ColorOption(name: "深海蓝", color: Color(red: 0.0, green: 0.25, blue: 0.5)),
        ColorOption(name: "湖水蓝", color: Color(red: 0.3, green: 0.7, blue: 0.8)),
        ColorOption(name: "天青蓝", color: Color(red: 0.5, green: 0.7, blue: 0.9)),
        ColorOption(name: "碧波蓝", color: Color(red: 0.2, green: 0.6, blue: 0.8)),
        ColorOption(name: "星空蓝", color: Color(red: 0.1, green: 0.2, blue: 0.5)),
        
        // 紫色系
        ColorOption(name: "云霞紫", color: Color(red: 0.7, green: 0.4, blue: 0.9)),
        ColorOption(name: "紫藤蓝", color: Color(red: 0.5, green: 0.5, blue: 0.8)),
        ColorOption(name: "夜樱紫", color: Color(red: 0.5, green: 0.1, blue: 0.3)),
        ColorOption(name: "琉璃紫", color: Color(red: 0.6, green: 0.3, blue: 0.7)),
        ColorOption(name: "丁香紫", color: Color(red: 0.7, green: 0.6, blue: 0.8)),
    ]
    
    // 计算理想的饱和度值，让颜色看起来最接近原始选择的颜色
    func idealSaturationFor(color: Color) -> Double {
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // 检查是否是白色或浅色
        if red > 0.9 && green > 0.9 && blue > 0.9 {
            return 1.0 // 白色默认饱和度为1.0，正好是中间位置
        }
        
        // 检查是否是黑色或深色
        if red < 0.1 && green < 0.1 && blue < 0.1 {
            return 1.5 // 黑色需要更高的饱和度来保持深色效果
        }
        
        // 检查是否是灰色
        let maxChannel = max(red, max(green, blue))
        let minChannel = min(red, min(green, blue))
        let colorDifference = maxChannel - minChannel
        
        if colorDifference < 0.1 {
            // 灰色系根据明度调整
            let brightness = (red + green + blue) / 3
            if brightness < 0.3 { // 深灰色
                return 1.5
            } else if brightness < 0.7 { // 中灰色
                return 1.0
            } else { // 浅灰色
                return 0.8
            }
        }
        
        // 彩色：获取其HSB值
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &alpha)
        
        // 根据原始颜色的饱和度计算理想饱和度
        // 低饱和度颜色需要提高饱和度，高饱和度颜色适当降低
        if s < 0.3 {
            return 1.5 // 原始饱和度低，提高
        } else if s > 0.7 {
            return 0.8 // 原始饱和度高，降低
        } else {
            return 1.0 // 中等饱和度，保持默认
        }
    }
    
    // 修改颜色处理逻辑，使屏幕显示更接近原始选择的颜色
    var filteredColor: Color {
        // 从颜色中提取RGB值
        let uiColor = UIColor(selectedColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // 白色系特殊处理：保持原始颜色，只调整亮度
        if red > 0.9 && green > 0.9 && blue > 0.9 {
            return selectedColor
        }
        
        // 黑色系特殊处理：保持黑色的纯度
        if red < 0.1 && green < 0.1 && blue < 0.1 {
            // 黑色系可以保持原样
            return selectedColor
        }
        
        // 检查是否是灰色
        let maxChannel = max(red, max(green, blue))
        let minChannel = min(red, min(green, blue))
        let colorDifference = maxChannel - minChannel
        
        // 如果颜色差异很小，认为是灰色
        if colorDifference < 0.1 {
            // 灰色系也基本保持原样
            return selectedColor
        }
        
        // 对于有彩色的颜色，使用饱和度作为增强因子，但保持原始色相和亮度
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        
        if uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &alpha) {
            // 饱和度范围是0-2，1.0是正常值，<1减弱饱和度，>1增强饱和度
            let adjustedSaturation = s * CGFloat(saturation)
            // 限制在合理范围内
            let finalSaturation = min(1.0, max(0.0, adjustedSaturation))
            
            return Color(UIColor(hue: h, saturation: finalSaturation, brightness: b, alpha: alpha))
        }
        
        // 如果以上方法都失败，返回原始颜色
        return selectedColor
    }
    
    var body: some View {
        ZStack {
            // 背景颜色作为补光
            filteredColor
                .ignoresSafeArea()
            
            // 相机活动时添加底层的全屏拍照按钮
            // 将全屏点击移到最底层，这样不会干扰预览框的交互
            if cameraViewModel.isShowingCamera {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        cameraViewModel.capturePhoto()
                    }
                    .allowsHitTesting(true)
            }
            
            // 相机预览 - 仅在isShowingCamera为true且captureSession存在时显示
            if cameraViewModel.isShowingCamera, let session = cameraViewModel.captureSession {
                GeometryReader { geometry in
                    ZStack {
                        // 使用新的相机预览实现
                        CameraPreview(captureSession: session)
                            .frame(width: geometry.size.width * 0.4, height: geometry.size.width * 0.4 * 4/3)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .clipped()
                            .shadow(radius: 5)
                            .scaleEffect(previewScale)
                            .offset(previewOffset)
                            // 确保手势可以正常工作，提高优先级
                            .highPriorityGesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        self.previewOffset = CGSize(
                                            width: self.lastOffset.width + gesture.translation.width,
                                            height: self.lastOffset.height + gesture.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        self.lastOffset = self.previewOffset
                                    }
                            )
                            // 使用simultaneousGesture确保缩放手势可以与拖动手势同时工作
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / self.lastScale
                                        self.lastScale = value
                                        let newScale = self.previewScale * delta
                                        self.previewScale = min(max(newScale, 0.5), 2.0)
                                    }
                                    .onEnded { _ in
                                        self.lastScale = 1.0
                                    }
                            )
                            // 添加点击拍照的手势，但优先级低于拖动和缩放
                            .onTapGesture {
                                cameraViewModel.capturePhoto()
                            }
                            .animation(.easeInOut(duration: 0.2), value: previewOffset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.opacity)
                .animation(.easeInOut, value: cameraViewModel.isShowingCamera)
            }
            // 错误显示
            else if let error = cameraViewModel.cameraError {
                // 显示相机错误信息
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                        .padding()
                    
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button(action: {
                        cameraViewModel.cameraError = nil
                        cameraViewModel.checkPermissionsAndSetupCamera()
                    }) {
                        Text("retry".localized)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding()
                }
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding()
            }
            
            // 控制面板
            VStack {
                Spacer()
                
                // 控制面板背景
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 200)
                    
                    VStack(spacing: 15) {
                        HStack(spacing: 15) {
                            // 颜色选择器按钮
                            Button(action: {
                                showColorPicker.toggle()
                            }) {
                                HStack {
                                    LocalizedText("select_color", font: .system(size: 14), color: .white)
                                    
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(selectedColor)
                                        .frame(width: 24, height: 24)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(8)
                            }
                            
                            Spacer()
                            
                            // 摄像头控制按钮
                            Button(action: toggleCamera) {
                                Image(systemName: cameraViewModel.isShowingCamera ? "camera.fill.badge.ellipsis" : "camera")
                                    .font(.system(size: 20))
                                    .padding(10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 3)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 亮度调节 - 保持统一布局
                        HStack {
                            Image(systemName: "sun.min")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 20)
                            
                            Slider(value: $brightness, in: 0.1...1.0)
                                .accentColor(.yellow)
                                .onChange(of: brightness) { newValue in
                                    UIScreen.main.brightness = newValue
                                }
                            
                            Text(String(format: "%.0f%%", brightness * 100))
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .frame(width: 40, alignment: .trailing)
                            
                            Image(systemName: "sun.max")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 20)
                        }
                        .padding(.horizontal)
                        
                        // 饱和度调节 - 保持统一布局
                        HStack {
                            Image(systemName: "drop")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 20)
                            
                            Slider(value: $saturation, in: 0...2)
                                .accentColor(.blue)
                                .onChange(of: saturation) { newValue in
                                    // 记录当前颜色的饱和度设置
                                    colorSaturationMap[selectedColor.description] = newValue
                                }
                            
                            Text(String(format: "%.0f%%", saturation * 50))
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .frame(width: 40, alignment: .trailing)
                            
                            Image(systemName: "drop.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 20)
                        }
                        .padding(.horizontal)
                        
                        // 操作提示
                        LocalizedText("operation_guide", font: .caption2, color: .white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, -5)
                    }
                    .padding(.vertical)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            
            // 颜色选择面板
            if showColorPicker {
                ZStack {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                    
                    VStack {
                        LocalizedText("select_light_color", font: .headline, color: .white)
                            .padding()
                        
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                                ForEach(colorOptions) { option in
                                    Button(action: {
                                        // 应用新颜色，并设置理想饱和度
                                        applyNewColor(option.color)
                                    }) {
                                        VStack {
                                            Circle()
                                                .fill(option.color)
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: selectedColor.description == option.color.description ? 3 : 0)
                                                )
                                            
                                            Text(option.name)
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                        .padding(.vertical, 5)
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        Button(action: {
                            showColorPicker = false
                        }) {
                            LocalizedText("close", font: .body, color: .white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                                .padding(.bottom)
                        }
                    }
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    .padding()
                }
                .transition(.opacity)
            }
            
            // Toast提示
            if cameraViewModel.showToast {
                VStack {
                    Spacer()
                    ToastView(message: cameraViewModel.toastMessage)
                    Spacer()
                        .frame(height: 300) // 将Toast放在控制面板上方
                }
                .transition(.opacity)
                .animation(.easeInOut, value: cameraViewModel.showToast)
            }
        }
        .onAppear {
            // 保存原始亮度
            originalBrightness = UIScreen.main.brightness
            setupVolumeButtonListener()
            
            // 不再自动初始化相机，默认关闭预览
            // cameraViewModel.checkPermissionsAndSetupCamera()
        }
        .onDisappear {
            // 恢复原始亮度
            UIScreen.main.brightness = originalBrightness
            
            if let observer = volumeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            cameraViewModel.stopSession()
        }
    }
    
    func setupVolumeButtonListener() {
        let volumeView = MPVolumeView()
        volumeView.isHidden = true
        
        // 使用新的API获取窗口
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(volumeView)
        }
        
        volumeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil,
            queue: .main) { _ in
                if cameraViewModel.isShowingCamera {
                    cameraViewModel.capturePhoto()
                }
            }
    }
    
    func toggleCamera() {
        print("切换相机状态，当前状态: \(cameraViewModel.isShowingCamera)")
        
        if cameraViewModel.isShowingCamera {
            // 正在显示相机，需要关闭它
            print("准备关闭相机")
            cameraViewModel.stopSession()
        } else {
            // 相机未显示，需要打开它
            print("准备打开相机")
            if cameraViewModel.captureSession == nil {
                // 第一次点击按钮时初始化相机
                print("初始化相机并打开")
                cameraViewModel.checkPermissionsAndSetupCamera()
            } else {
                // 已经初始化过，直接启动会话
                print("直接启动相机会话")
                cameraViewModel.startSession()
            }
        }
    }
    
    // 应用新颜色并设置理想饱和度
    private func applyNewColor(_ newColor: Color) {
        // 设置新颜色
        selectedColor = newColor
        
        // 检查是否有保存的饱和度设置
        if let savedSaturation = colorSaturationMap[newColor.description] {
            // 使用保存的饱和度设置
            saturation = savedSaturation
        } else {
            // 计算并应用理想饱和度
            saturation = idealSaturationFor(color: newColor)
            // 保存这个理想饱和度供将来使用
            colorSaturationMap[newColor.description] = saturation
        }
        
        // 关闭颜色选择器
        showColorPicker = false
    }
}

// 扩展UIColor以便检查亮度
extension UIColor {
    var brightness: CGFloat {
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        if self.getWhite(&white, alpha: &alpha) {
            return white
        }
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return brightness
    }
}

#Preview {
    ContentView()
} 
