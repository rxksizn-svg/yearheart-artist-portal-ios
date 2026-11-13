import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: BrowserController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class BrowserController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let browser: WKWebView
    private let home: URL
    private var observation: NSKeyValueObservation?
    private let address = UILabel()
    private let errorLabel = UILabel()
    private var backButton: UIBarButtonItem!
    private var forwardButton: UIBarButtonItem!
    private var popups: [WKWebView] = []

    init(configuration: WKWebViewConfiguration? = nil) {
        home = URL(string: Bundle.main.object(forInfoDictionaryKey: "PortalURL") as! String)!
        let config = configuration ?? WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        browser = WKWebView(frame: .zero, configuration: config)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        browser.navigationDelegate = self; browser.uiDelegate = self
        browser.allowsBackForwardNavigationGestures = true
        browser.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browser)
        errorLabel.numberOfLines = 0; errorLabel.textAlignment = .center
        errorLabel.backgroundColor = .secondarySystemBackground
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.isHidden = true; view.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            browser.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            browser.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            browser.leadingAnchor.constraint(equalTo: view.leadingAnchor), browser.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor), errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.85)
        ])
        address.font = .preferredFont(forTextStyle: .caption1)
        address.adjustsFontSizeToFitWidth = true; address.text = home.host
        navigationItem.titleView = address
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reload)),
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share))
        ]
        backButton = UIBarButtonItem(title: "ย้อนกลับ", style: .plain, target: self, action: #selector(back))
        forwardButton = UIBarButtonItem(title: "ถัดไป", style: .plain, target: self, action: #selector(forward))
        toolbarItems = [backButton, forwardButton, UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "หน้าแรก", style: .plain, target: self, action: #selector(goHome)),
            UIBarButtonItem(title: "ล้าง Session", style: .plain, target: self, action: #selector(clearSession))]
        navigationController?.isToolbarHidden = false
        observation = browser.observe(\.url, options: [.new]) { [weak self] web, _ in
            self?.address.text = web.url?.host
            self?.backButton.isEnabled = web.canGoBack; self?.forwardButton.isEnabled = web.canGoForward
        }
        goHome()
    }
    @objc private func goHome() { browser.load(URLRequest(url: home)) }
    @objc private func reload() { errorLabel.isHidden = true; if browser.url == nil { goHome() } else { browser.reload() } }
    @objc private func back() { browser.goBack() }
    @objc private func forward() { browser.goForward() }
    @objc private func share() {
        guard let url = browser.url else { return }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        present(sheet, animated: true)
    }
    @objc private func clearSession() {
        let alert = UIAlertController(title: "ล้างข้อมูลเข้าสู่ระบบ?", message: "ล้าง Cookie และข้อมูลเว็บไซต์เฉพาะแอปนี้ ไม่ได้ออกจากบัญชีบนอุปกรณ์อื่น", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ยกเลิก", style: .cancel))
        alert.addAction(UIAlertAction(title: "ล้างข้อมูล", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.browser.stopLoading()
            WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { self.goHome() }
        })
        present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if ["https", "blob", "about"].contains(url.scheme?.lowercased() ?? "") { decisionHandler(.allow); return }
        decisionHandler(.cancel)
        if action.navigationType == .linkActivated, ["mailto", "tel"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { errorLabel.isHidden = true }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        errorLabel.text = "เปิดหน้าเว็บไม่สำเร็จ\nตรวจสอบอินเทอร์เน็ตแล้วกดรีเฟรช"; errorLabel.isHidden = false
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard action.request.url?.scheme == "https" || action.request.url?.absoluteString == "about:blank" else { return nil }
        // Keep the supplied configuration so opener/SSO popup relationships survive.
        let popup = WKWebView(frame: view.bounds, configuration: configuration)
        popup.navigationDelegate = self; popup.uiDelegate = self
        popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(popup); popups.append(popup)
        return popup
    }
    func webViewDidClose(_ webView: WKWebView) { webView.removeFromSuperview(); popups.removeAll { $0 === webView } }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: frame.request.url?.host, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ตกลง", style: .default) { _ in completionHandler() }); present(alert, animated: true)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: frame.request.url?.host, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ยกเลิก", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "ตกลง", style: .default) { _ in completionHandler(true) }); present(alert, animated: true)
    }
}
