//
//  ViewController.swift
//  LocationKitProject
//
//  Test ViewController for LocationKit Facade
//  Demonstrates camera context, nearby search, and address search scenarios
//

import UIKit
import LocationKitProject

class ViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var logTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.isEditable = false
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return textView
    }()
    
    private lazy var searchTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "输入地址搜索..."
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .search
        textField.delegate = self
        textField.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)
        return textField
    }()
    
    private lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private lazy var travelButton: UIButton = {
        let button = createButton(title: "🌍 Travel", color: .systemBlue)
        button.addTarget(self, action: #selector(travelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var workButton: UIButton = {
        let button = createButton(title: "💼 Work", color: .systemGreen)
        button.addTarget(self, action: #selector(workButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var burstButton: UIButton = {
        let button = createButton(title: "📸 Burst", color: .systemOrange)
        button.addTarget(self, action: #selector(burstButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var addressButton: UIButton = {
        let button = createButton(title: "📍 地址", color: .systemPurple)
        button.addTarget(self, action: #selector(addressButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var historyButton: UIButton = {
        let button = createButton(title: "🕐 历史", color: .systemTeal)
        button.addTarget(self, action: #selector(historyButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var poiButton: UIButton = {
        let button = createButton(title: "🏪 POI", color: .systemIndigo)
        button.addTarget(self, action: #selector(poiButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var clearButton: UIButton = {
        let button = createButton(title: "🗑️ 清除", color: .systemRed)
        button.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.text = "Ready"
        return label
    }()
    
    // MARK: - Properties
    
    private var logMessages: [String] = []
    private var isLoading = false {
        didSet {
            updateLoadingState()
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        appendLog("📱 LocationKit Test Ready")
        appendLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        appendLog("• Travel/Work: 相机位置上下文")
        appendLog("• Burst: 连拍缓存测试")
        appendLog("• 地址: 当前位置 + 默认地址列表")
        appendLog("• POI: 周边兴趣点测试")
        appendLog("• 历史: 搜索历史记录")
        appendLog("• 搜索框: 输入文字实时联想")
        appendLog("")
        
        // Request permission on launch
        requestLocationPermission()
        
        // 自动加载默认内容
        showDefaultContent()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(searchTextField)
        view.addSubview(logTextView)
        view.addSubview(buttonStackView)
        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)
        
        // Add buttons to stack (row 1)
        buttonStackView.addArrangedSubview(travelButton)
        buttonStackView.addArrangedSubview(workButton)
        buttonStackView.addArrangedSubview(burstButton)
        
        // Secondary button row (row 2)
        let secondaryStack = UIStackView()
        secondaryStack.translatesAutoresizingMaskIntoConstraints = false
        secondaryStack.axis = .horizontal
        secondaryStack.spacing = 8
        secondaryStack.distribution = .fillEqually
        secondaryStack.addArrangedSubview(addressButton)
        secondaryStack.addArrangedSubview(poiButton)
        secondaryStack.addArrangedSubview(historyButton)
        view.addSubview(secondaryStack)
        
        // Third button row (row 3)
        let thirdStack = UIStackView()
        thirdStack.translatesAutoresizingMaskIntoConstraints = false
        thirdStack.axis = .horizontal
        thirdStack.spacing = 8
        thirdStack.distribution = .fillEqually
        thirdStack.addArrangedSubview(clearButton)
        view.addSubview(thirdStack)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Search TextField
            searchTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            searchTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Log TextView
            logTextView.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 12),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logTextView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),
            
            // Status Label
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -12),
            statusLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // Button Stack (row 1)
            buttonStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: secondaryStack.topAnchor, constant: -8),
            buttonStackView.heightAnchor.constraint(equalToConstant: 44),
            
            // Secondary Stack (row 2)
            secondaryStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            secondaryStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            secondaryStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            secondaryStack.heightAnchor.constraint(equalToConstant: 44),
            
            // Activity Indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: logTextView.centerYAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        title = "LocationKit Demo"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        let clearCacheButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(clearCacheTapped)
        )
        navigationItem.rightBarButtonItem = clearCacheButton
    }
    
    private func createButton(title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    // MARK: - Actions
    
    @objc private func travelButtonTapped() {
        guard !isLoading else { return }
        view.endEditing(true)
        
        appendLog("\n🌍 ═══════ TRAVEL MODE ═══════")
        fetchContext(scene: .travel, mode: .accurate)
    }
    
    @objc private func workButtonTapped() {
        guard !isLoading else { return }
        view.endEditing(true)
        
        appendLog("\n💼 ═══════ WORK MODE ═══════")
        fetchContext(scene: .work, mode: .fast)
    }
    
    @objc private func burstButtonTapped() {
        guard !isLoading else { return }
        view.endEditing(true)
        
        appendLog("\n📸 ═══════ BURST TEST (5 calls) ═══════")
        appendLog("Testing cache mechanism...")
        appendLog("Expected: 1st MISS, 2-5 HIT with different timestamps")
        appendLog("")
        
        performBurstTest()
    }
    
    @objc private func addressButtonTapped() {
        guard !isLoading else { return }
        view.endEditing(true)
        
        appendLog("\n📍 ═══════ 默认地址列表 ═══════")
        appendLog("获取当前位置 + 历史记录...")
        appendLog("")
        
        performAddressTest()
    }
    
    @objc private func historyButtonTapped() {
        guard !isLoading else { return }
        view.endEditing(true)
        
        appendLog("\n🕐 ═══════ 搜索历史 ═══════")
        showSearchHistory()
    }
    
    @objc private func poiButtonTapped() {
        guard !isLoading else { return }
        view.endEditing(true)
        
        appendLog("\n🏪 ═══════ 周边 POI 测试 ═══════")
        appendLog("获取周边兴趣点（搜索框为空时的默认内容）...")
        appendLog("")
        
        performPOITest()
    }
    
    @objc private func clearButtonTapped() {
        logMessages.removeAll()
        logTextView.text = ""
        appendLog("📱 Log cleared")
        appendLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    @objc private func clearCacheTapped() {
        LocationKit.shared.clearCache()
        LocationKit.shared.clearNearbyCache()
        LocationKit.shared.clearAddressSearchHistory()
        appendLog("\n🗑️ 所有缓存和历史已清除")
    }
    
    // MARK: - Search Text Changed
    
    @objc private func searchTextChanged(_ textField: UITextField) {
        let query = textField.text ?? ""
        
        if query.isEmpty {
            statusLabel.text = "Ready"
            return
        }
        
        statusLabel.text = "搜索中..."
        
        // 使用实时搜索 API
        LocationKit.shared.searchAddressRealtime(query) { [weak self] results in
            DispatchQueue.main.async {
                self?.handleSearchResults(results, query: query)
            }
        } onError: { [weak self] error in
            DispatchQueue.main.async {
                self?.appendLog("⚠️ 搜索错误: \(error.localizedDescription)")
                self?.statusLabel.text = "搜索错误"
            }
        }
    }
    
    private func handleSearchResults(_ results: [AddressSearchResult], query: String) {
        statusLabel.text = "找到 \(results.count) 个结果"
        
        // 清空之前的搜索日志，只显示最新结果
        appendLog("")
        appendLog("🔍 搜索 '\(query)' 结果:")
        
        if results.isEmpty {
            appendLog("  未找到匹配的地址")
        } else {
            for (index, result) in results.prefix(8).enumerated() {
                appendLog("  \(index + 1). \(result.title)")
                if !result.subtitle.isEmpty {
                    appendLog("     📍 \(result.subtitle)")
                }
            }
            if results.count > 8 {
                appendLog("  ... 还有 \(results.count - 8) 个结果")
            }
        }
    }
    
    // MARK: - Location Permission
    
    private func requestLocationPermission() {
        Task {
            let status = await LocationManager.shared.requestPermission(type: .whenInUse)
            await MainActor.run {
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    appendLog("✅ Location permission granted")
                    // 设置搜索区域为当前位置
                    Task {
                        await LocationKit.shared.setAddressSearchRegionToCurrent()
                    }
                case .denied:
                    appendLog("❌ Location permission denied")
                    showPermissionAlert()
                case .restricted:
                    appendLog("⚠️ Location permission restricted")
                case .notDetermined:
                    appendLog("⏳ Location permission not determined")
                @unknown default:
                    appendLog("❓ Unknown permission status")
                }
            }
        }
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "需要位置权限",
            message: "请在设置中启用位置访问以使用 LocationKit 功能。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "打开设置", style: .default) { _ in
            LocationManager.openAppSettings()
        })
        present(alert, animated: true)
    }
    
    // MARK: - Fetch Methods
    
    private func fetchContext(scene: LocationScene, mode: LocationMode) {
        isLoading = true
        statusLabel.text = "Fetching \(scene.displayName)..."
        
        Task {
            do {
                let startTime = Date()
                let context = try await LocationKit.shared.fetchCameraContext(scene: scene, mode: mode)
                let elapsed = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    logContext(context, elapsed: elapsed)
                    isLoading = false
                    statusLabel.text = "Completed in \(String(format: "%.2f", elapsed))s"
                }
            } catch {
                await MainActor.run {
                    appendLog("❌ Error: \(error.localizedDescription)")
                    isLoading = false
                    statusLabel.text = "Error"
                }
            }
        }
    }
    
    private func performBurstTest() {
        isLoading = true
        statusLabel.text = "Burst test in progress..."
        
        Task {
            var cacheHits = 0
            var timestamps: [String] = []
            
            for i in 1...5 {
                do {
                    if i > 1 {
                        try await Task.sleep(nanoseconds: 500_000_000)
                    }
                    
                    let context = try await LocationKit.shared.fetchBurstContext()
                    
                    await MainActor.run {
                        let cacheStatus = context.flags.isCache ? "✅ CACHE HIT" : "🔄 CACHE MISS"
                        if context.flags.isCache {
                            cacheHits += 1
                        }
                        timestamps.append(context.display.timeStr)
                        
                        appendLog("━━━ Call #\(i) ━━━")
                        appendLog("  Status: \(cacheStatus)")
                        appendLog("  TimeStr: \(context.display.timeStr)")
                        appendLog("  Title: \(context.display.title)")
                    }
                } catch {
                    await MainActor.run {
                        appendLog("❌ Call #\(i) Error: \(error.localizedDescription)")
                    }
                }
            }
            
            await MainActor.run {
                appendLog("")
                appendLog("📊 ═══════ BURST SUMMARY ═══════")
                appendLog("  Cache Hits: \(cacheHits)/4 expected")
                appendLog("  Unique Timestamps: \(Set(timestamps).count)")
                
                if Set(timestamps).count == 5 {
                    appendLog("  ✅ All timestamps are unique (PASS)")
                } else {
                    appendLog("  ⚠️ Some timestamps duplicated (CHECK)")
                }
                
                isLoading = false
                statusLabel.text = "Burst test completed"
            }
        }
    }
    
    // MARK: - Address Test
    
    private func performAddressTest() {
        isLoading = true
        statusLabel.text = "获取默认地址列表..."
        
        Task {
            let startTime = Date()
            
            // Test 1: 获取当前位置地址
            appendLog("📍 Test 1: 获取当前位置地址...")
            do {
                if let currentAddress = try await LocationKit.shared.getCurrentLocationAddress() {
                    appendLog("  ✅ 当前位置:")
                    appendLog("    名称: \(currentAddress.name ?? "N/A")")
                    appendLog("    地址: \(currentAddress.formattedAddress)")
                    appendLog("    城市: \(currentAddress.city ?? "N/A")")
                    appendLog("    区县: \(currentAddress.district ?? "N/A")")
                    appendLog("    坐标: \(currentAddress.latitude), \(currentAddress.longitude)")
                    
                    // 添加到历史记录
                    LocationKit.shared.addAddressToHistory(currentAddress)
                    appendLog("    → 已添加到历史记录")
                } else {
                    appendLog("  ⚠️ 无法获取当前位置地址")
                }
            } catch {
                appendLog("  ❌ 错误: \(error.localizedDescription)")
            }
            
            // Test 2: 获取默认展示内容
            appendLog("")
            appendLog("📋 Test 2: 获取默认展示内容（当前位置 + 历史）...")
            let defaultAddresses = await LocationKit.shared.getDefaultAddresses()
            appendLog("  找到 \(defaultAddresses.count) 个地址:")
            
            for (index, address) in defaultAddresses.prefix(5).enumerated() {
                let tag = address.isCurrentLocation ? "📍当前" : (address.isFromHistory ? "🕐历史" : "")
                appendLog("  \(index + 1). \(address.name ?? address.formattedAddress) \(tag)")
                appendLog("     \(address.city ?? "") \(address.district ?? "") \(address.street ?? "")")
            }
            
            // Test 3: 搜索地址
            appendLog("")
            appendLog("🔍 Test 3: 搜索 '星巴克'...")
            do {
                let results = try await LocationKit.shared.searchAddress(query: "星巴克")
                appendLog("  找到 \(results.count) 个结果:")
                
                for (index, result) in results.prefix(5).enumerated() {
                    appendLog("  \(index + 1). \(result.title)")
                    if !result.subtitle.isEmpty {
                        appendLog("     📍 \(result.subtitle)")
                    }
                }
                
                // Test 4: 获取第一个结果的详情
                if let firstResult = results.first {
                    appendLog("")
                    appendLog("📝 Test 4: 获取详情 '\(firstResult.title)'...")
                    
                    if let details = try await LocationKit.shared.getAddressDetails(from: firstResult) {
                        appendLog("  名称: \(details.name ?? "N/A")")
                        appendLog("  完整地址: \(details.formattedAddress)")
                        appendLog("  城市: \(details.city ?? "N/A")")
                        appendLog("  坐标: \(details.latitude), \(details.longitude)")
                        
                        // 添加到历史
                        LocationKit.shared.addAddressToHistory(details)
                        appendLog("  → 已添加到历史记录")
                    }
                }
            } catch {
                appendLog("  ❌ 搜索错误: \(error.localizedDescription)")
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                appendLog("")
                appendLog("✅ 地址测试完成，耗时 \(String(format: "%.2f", elapsed))s")
                isLoading = false
                statusLabel.text = "地址测试完成"
            }
        }
    }
    
    // MARK: - POI Test
    
    private func performPOITest() {
        isLoading = true
        statusLabel.text = "获取周边 POI..."
        
        Task {
            let startTime = Date()
            
            // Test 1: 获取 100m 内的 POI
            appendLog("📍 Test 1: 获取 100m 内的兴趣点...")
            do {
                let poi100m = try await LocationKit.shared.getNearbyPOI(radius: 100, limit: 10)
                appendLog("  找到 \(poi100m.count) 个兴趣点 (100m):")
                
                for (index, poi) in poi100m.prefix(5).enumerated() {
                    let distStr = poi.distanceString ?? "?"
                    appendLog("  \(index + 1). \(poi.name ?? "Unknown") - \(distStr)")
                    appendLog("     📍 \(poi.formattedAddress)")
                }
                if poi100m.count > 5 {
                    appendLog("  ... 还有 \(poi100m.count - 5) 个")
                }
            } catch {
                appendLog("  ❌ 错误: \(error.localizedDescription)")
            }
            
            // Test 2: 获取 500m 内的 POI
            appendLog("")
            appendLog("🏬 Test 2: 获取 500m 内的兴趣点...")
            do {
                let poi500m = try await LocationKit.shared.getNearbyPOI(radius: 500, limit: 15)
                appendLog("  找到 \(poi500m.count) 个兴趣点 (500m):")
                
                for (index, poi) in poi500m.prefix(8).enumerated() {
                    let distStr = poi.distanceString ?? "?"
                    appendLog("  \(index + 1). \(poi.name ?? "Unknown") - \(distStr)")
                }
                if poi500m.count > 8 {
                    appendLog("  ... 还有 \(poi500m.count - 8) 个")
                }
            } catch {
                appendLog("  ❌ 错误: \(error.localizedDescription)")
            }
            
            // Test 3: 根据关键词获取 POI
            appendLog("")
            appendLog("☕ Test 3: 获取 300m 内的咖啡店...")
            do {
                let cafes = try await LocationKit.shared.getPOIByKeyword("咖啡", radius: 300, limit: 5)
                appendLog("  找到 \(cafes.count) 家咖啡店:")
                
                for (index, cafe) in cafes.enumerated() {
                    let distStr = cafe.distanceString ?? "?"
                    appendLog("  \(index + 1). \(cafe.name ?? "Unknown") - \(distStr)")
                }
            } catch {
                appendLog("  ❌ 错误: \(error.localizedDescription)")
            }
            
            // Test 4: 获取多类型 POI
            appendLog("")
            appendLog("🏪 Test 4: 获取多类型 POI (餐厅、便利店、银行)...")
            let multiPOI = await LocationKit.shared.getNearbyPOIByCategories(
                radius: 500,
                categories: ["餐厅", "便利店", "银行"],
                limitPerCategory: 3
            )
            appendLog("  找到 \(multiPOI.count) 个地点:")
            
            for (index, poi) in multiPOI.prefix(10).enumerated() {
                let distStr = poi.distanceString ?? "?"
                let category = poi.category ?? "未知"
                appendLog("  \(index + 1). \(poi.name ?? "Unknown") [\(category)] - \(distStr)")
            }
            
            // Test 5: 增强版默认地址列表（包含 POI）
            appendLog("")
            appendLog("📋 Test 5: 增强版默认地址列表...")
            let defaultWithPOI = await LocationKit.shared.getDefaultAddressesWithPOI(
                nearbyRadius: 200,
                nearbyLimit: 5
            )
            appendLog("  找到 \(defaultWithPOI.count) 个地址:")
            
            for (index, addr) in defaultWithPOI.prefix(8).enumerated() {
                let tag: String
                if addr.isCurrentLocation {
                    tag = "📍当前"
                } else if addr.isFromHistory {
                    tag = "🕐历史"
                } else {
                    tag = "🏪POI"
                }
                let distStr = addr.distanceString ?? ""
                appendLog("  \(index + 1). \(addr.name ?? addr.formattedAddress) \(tag) \(distStr)")
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                appendLog("")
                appendLog("✅ POI 测试完成，耗时 \(String(format: "%.2f", elapsed))s")
                isLoading = false
                statusLabel.text = "POI 测试完成"
            }
        }
    }
    
    // MARK: - Default Content (搜索框为空时的默认展示)
    
    /// 显示默认内容：当前位置 + 周边 POI + 历史记录
    /// 模拟用户打开地址选择器时搜索框为空的场景
    private func showDefaultContent() {
        appendLog("\n📋 ═══════ 加载默认内容 ═══════")
        appendLog("搜索框为空时展示：当前位置 + 周边 POI + 历史")
        appendLog("")
        
        Task {
            statusLabel.text = "加载默认内容..."
            
            // 使用增强版 API: 当前位置 + 周边 POI + 历史记录
            let addresses = await LocationKit.shared.getDefaultAddressesWithPOI(
                nearbyRadius: 1000,  // 200米内的 POI
                nearbyLimit: 20    // 最多 8 个 POI
            )
            
            await MainActor.run {
                if addresses.isEmpty {
                    appendLog("  ⚠️ 无法获取位置信息")
                    appendLog("  请确保已授权位置权限")
                    statusLabel.text = "无位置信息"
                    return
                }
                
                appendLog("📍 默认展示列表 (\(addresses.count) 项):")
                appendLog("─────────────────────────────────")
                
                for (index, addr) in addresses.enumerated() {
                    // 确定标签
                    let tag: String
                    let emoji: String
                    if addr.isCurrentLocation {
                        tag = "当前位置"
                        emoji = "📍"
                    } else if addr.isFromHistory {
                        tag = "历史记录"
                        emoji = "🕐"
                    } else {
                        tag = "周边 POI"
                        emoji = "🏪"
                    }
                    
                    // 距离信息
                    let distStr = addr.distanceString ?? ""
                    
                    appendLog("\(emoji) \(index + 1). \(addr.name ?? addr.formattedAddress)")
                    appendLog("   [\(tag)] \(distStr)")
                    
                    // 显示详细地址（如果有）
                    let detailParts = [addr.city, addr.district, addr.street].compactMap { $0 }.joined(separator: " ")
                    if !detailParts.isEmpty {
                        appendLog("   📮 \(detailParts)")
                    }
                    appendLog("")
                }
                
                appendLog("─────────────────────────────────")
                appendLog("💡 这就是搜索框为空时应该展示的内容")
                
                statusLabel.text = "已加载 \(addresses.count) 项"
            }
        }
    }
    
    // MARK: - Search History
    
    private func showSearchHistory() {
        let history = LocationKit.shared.getAddressSearchHistory()
        
        appendLog("  历史记录数量: \(history.count)")
        appendLog("")
        
        if history.isEmpty {
            appendLog("  📭 暂无搜索历史")
            appendLog("  提示: 点击 '地址' 按钮或搜索地址后会自动保存")
        } else {
            for (index, address) in history.enumerated() {
                appendLog("  \(index + 1). \(address.name ?? address.formattedAddress)")
                appendLog("     📍 \(address.city ?? "") \(address.district ?? "")")
            }
            
            appendLog("")
            appendLog("  💡 点击右上角刷新按钮可清除历史")
        }
    }
    
    // MARK: - Logging
    
    private func logContext(_ context: CameraLocationContext, elapsed: TimeInterval) {
        appendLog("")
        appendLog("📍 ── Result ──")
        appendLog("  ┌─ Display ─────────────────────")
        appendLog("  │ Title: \(context.display.title)")
        appendLog("  │ Subtitle: \(context.display.subtitle)")
        appendLog("  │ Weather: \(context.display.weatherStr)")
        appendLog("  │ TimeStr: \(context.display.timeStr)")
        appendLog("  │ Altitude: \(context.display.altitudeStr)")
        appendLog("  │ Coordinate: \(context.display.coordinateStr)")
        appendLog("  └────────────────────────────────")
        appendLog("")
        appendLog("  ┌─ Weather Details ────────────")
        if let weather = context.raw.weather {
            appendLog("  │ Condition: \(weather.condition)")
            appendLog("  │ Temperature: \(String(format: "%.1f", weather.temperature))°C")
            appendLog("  │ Humidity: \(weather.humidity)%")
            appendLog("  │ Icon: \(weather.iconName)")
        } else {
            appendLog("  │ Weather: Not available")
        }
        appendLog("  └────────────────────────────────")
        appendLog("")
        appendLog("  ┌─ Flags ──────────────────────")
        appendLog("  │ IsCache: \(context.flags.isCache)")
        appendLog("  │ IsMock: \(context.flags.isMock)")
        appendLog("  │ WeatherTimedOut: \(context.flags.weatherTimedOut)")
        appendLog("  │ Scene: \(context.flags.scene.rawValue)")
        appendLog("  │ Mode: \(context.flags.mode.rawValue)")
        appendLog("  └────────────────────────────────")
        appendLog("")
        appendLog("  ⏱️ Elapsed: \(String(format: "%.2f", elapsed))s")
        appendLog("═══════════════════════════════════")
    }
    
    private func appendLog(_ message: String) {
        logMessages.append(message)
        let fullLog = logMessages.joined(separator: "\n")
        logTextView.text = fullLog
        
        // Scroll to bottom
        if fullLog.count > 0 {
            let bottom = NSRange(location: fullLog.count - 1, length: 1)
            logTextView.scrollRangeToVisible(bottom)
        }
    }
    
    private func updateLoadingState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let buttons = [self.travelButton, self.workButton, self.burstButton, self.addressButton, self.historyButton]
            
            for button in buttons {
                button.isEnabled = !self.isLoading
                button.alpha = self.isLoading ? 0.5 : 1.0
            }
            
            if self.isLoading {
                self.activityIndicator.startAnimating()
            } else {
                self.activityIndicator.stopAnimating()
            }
        }
    }
}

// MARK: - UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        // 执行搜索
        if let query = textField.text, !query.isEmpty {
            appendLog("\n🔍 ═══════ 搜索 '\(query)' ═══════")
            
            Task {
                do {
                    let results = try await LocationKit.shared.searchAddress(query: query)
                    await MainActor.run {
                        appendLog("  找到 \(results.count) 个结果:")
                        for (index, result) in results.prefix(10).enumerated() {
                            appendLog("  \(index + 1). \(result.title)")
                            if !result.subtitle.isEmpty {
                                appendLog("     📍 \(result.subtitle)")
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        appendLog("  ❌ 搜索错误: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        return true
    }
}
