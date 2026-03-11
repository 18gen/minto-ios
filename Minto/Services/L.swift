import Foundation

private var _cachedBundle: Bundle?
private var _cachedLanguage: AppLanguage?

private func localizedBundle() -> Bundle {
    let current = AppSettings.shared.language
    if let cached = _cachedBundle, _cachedLanguage == current { return cached }
    let path = Bundle.main.path(forResource: current.rawValue, ofType: "lproj")
    let bundle = path.flatMap { Bundle(path: $0) } ?? Bundle.main
    _cachedBundle = bundle
    _cachedLanguage = current
    return bundle
}

func L(_ key: String) -> String {
    localizedBundle().localizedString(forKey: key, value: nil, table: nil)
}

func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
