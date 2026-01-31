//
//  ViewController.swift
//  LocationKitProject
//
//  Test ViewController for LocationKit Facade
//  Demonstrates watermark camera and travel camera scenarios
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
    
    private lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 12
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
        let button = createButton(title: "📸 Burst x5", color: .systemOrange)
        button.addTarget(self, action: #selector(burstButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var clearButton: UIButton = {
        let button = createButton(title: "🗑️ Clear", color: .systemRed)
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
        appendLog("• Travel Mode: Scenic spots, POI, Weather")
        appendLog("• Work Mode: Office address, Timestamps")
        appendLog("• Burst Test: 5 rapid calls (cache test)")
        appendLog("")
        
        // Request permission on launch
        requestLocationPermission()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(logTextView)
        view.addSubview(buttonStackView)
        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)
        
        // Add buttons to stack
        buttonStackView.addArrangedSubview(travelButton)
        buttonStackView.addArrangedSubview(workButton)
        buttonStackView.addArrangedSubview(burstButton)
        
        // Secondary button row
        let secondaryStack = UIStackView()
        secondaryStack.translatesAutoresizingMaskIntoConstraints = false
        secondaryStack.axis = .horizontal
        secondaryStack.spacing = 12
        secondaryStack.distribution = .fillEqually
        secondaryStack.addArrangedSubview(clearButton)
        view.addSubview(secondaryStack)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Log TextView
            logTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logTextView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -12),
            
            // Status Label
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -12),
            statusLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // Button Stack
            buttonStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: secondaryStack.topAnchor, constant: -12),
            buttonStackView.heightAnchor.constraint(equalToConstant: 50),
            
            // Secondary Stack
            secondaryStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            secondaryStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            secondaryStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
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
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    // MARK: - Actions
    
    @objc private func travelButtonTapped() {
        guard !isLoading else { return }
        
        appendLog("\n🌍 ═══════ TRAVEL MODE ═══════")
        fetchContext(scene: .travel, mode: .accurate)
    }
    
    @objc private func workButtonTapped() {
        guard !isLoading else { return }
        
        appendLog("\n💼 ═══════ WORK MODE ═══════")
        fetchContext(scene: .work, mode: .fast)
    }
    
    @objc private func burstButtonTapped() {
        guard !isLoading else { return }
        
        appendLog("\n📸 ═══════ BURST TEST (5 calls) ═══════")
        appendLog("Testing cache mechanism...")
        appendLog("Expected: 1st MISS, 2-5 HIT with different timestamps")
        appendLog("")
        
        performBurstTest()
    }
    
    @objc private func clearButtonTapped() {
        logMessages.removeAll()
        logTextView.text = ""
        appendLog("📱 Log cleared")
        appendLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    @objc private func clearCacheTapped() {
        LocationKit.shared.clearCache()
        appendLog("\n🗑️ Cache cleared manually")
    }
    
    // MARK: - Location Permission
    
    private func requestLocationPermission() {
        Task {
            let status = await LocationManager.shared.requestPermission(type: .whenInUse)
            await MainActor.run {
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    appendLog("✅ Location permission granted")
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
            title: "Location Permission Required",
            message: "Please enable location access in Settings to use LocationKit features.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
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
                    // Small delay between calls to simulate burst shooting
                    if i > 1 {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
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
                
                // Verify timestamps are different
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
            if let attrURL = weather.attributionURL {
                appendLog("  │ Attribution: \(attrURL.absoluteString)")
            }
            if weather.attributionLogoURL != nil {
                appendLog("  │ Logo URL: Available ✓")
            }
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
        appendLog("  ┌─ POI List (\(context.raw.poiList.count) items) ─────")
        for poi in context.raw.poiList.prefix(3) {
            appendLog("  │ • \(poi.name) (\(poi.distanceStr))")
        }
        if context.raw.poiList.count > 3 {
            appendLog("  │ ... and \(context.raw.poiList.count - 3) more")
        }
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
        let bottom = NSRange(location: fullLog.count - 1, length: 1)
        logTextView.scrollRangeToVisible(bottom)
    }
    
    private func updateLoadingState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.travelButton.isEnabled = !self.isLoading
            self.workButton.isEnabled = !self.isLoading
            self.burstButton.isEnabled = !self.isLoading
            
            self.travelButton.alpha = self.isLoading ? 0.5 : 1.0
            self.workButton.alpha = self.isLoading ? 0.5 : 1.0
            self.burstButton.alpha = self.isLoading ? 0.5 : 1.0
            
            if self.isLoading {
                self.activityIndicator.startAnimating()
            } else {
                self.activityIndicator.stopAnimating()
            }
        }
    }
}
