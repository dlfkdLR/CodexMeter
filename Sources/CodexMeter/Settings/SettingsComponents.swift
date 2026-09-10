import AppKit
import SwiftUI

// MARK: - Sidebar

/// A rounded-square badge behind a white symbol — System Settings' own sidebar
/// icon style, ported from Codenotch.
struct SidebarIcon: View {
    let systemName: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
            .fill(tint.gradient)
            .frame(width: 20, height: 20)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
    }
}

/// Real window vibrancy — blends against what is *behind* the window, not what
/// is inside it, so the settings panel reads as a floating glass surface.
/// Ported from Codenotch's `VisualEffect`.
struct SettingsWindowVibrancy: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        apply(to: view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) { apply(to: view) }

    private func apply(to view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = .behindWindow
    }
}

/// One sidebar row: an icon chip, a single-line title, and an optional trailing
/// status dot. Categories get a tinted SF Symbol chip; providers show their real
/// logo on a neutral chip.
struct SettingsChipLabel: View {
    let title: String
    var systemImage: String?
    var logoProvider: UsageProvider?
    var tint: Color = .gray
    var statusDot: Color?
    var dimmed = false

    var body: some View {
        HStack(spacing: 8) {
            chip.accessibilityHidden(true)
            Text(title)
                .lineLimit(1)
                .foregroundStyle(dimmed ? Color.secondary : Color.primary)
            Spacer(minLength: 4)
            if let statusDot {
                Circle()
                    .fill(statusDot)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusDot != nil ? "\(title), on" : title)
        .accessibilityHint("Select to view this section.")
    }

    @ViewBuilder
    private var chip: some View {
        if let logoProvider {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .frame(width: 20, height: 20)
                .overlay(
                    ProviderLogo(provider: logoProvider, size: 13)
                        .foregroundStyle(dimmed ? Color.secondary : Color.primary)
                )
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.gradient)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: systemImage ?? "circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                )
        }
    }
}

struct SettingsSidebarSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search settings", text: $text)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search settings")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(6)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Detail primitives

/// A scrolling pane of grouped `SettingsSection` cards — CodexMeter's stand-in
/// for `Form { … }.formStyle(.grouped)`, floating on the settings window's
/// vibrancy. No in-pane title block: `SettingsView` draws the pane title fixed
/// above the scroll.
struct SettingsForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(.top, 4)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The inset a grouped section card keeps from the pane's edges.
private let settingsCardInset: CGFloat = 16

struct SettingsSection<Content: View>: View {
    var title: String?
    var trailingCaption: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    if let trailingCaption {
                        Text(trailingCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, settingsCardInset + 12)
                .accessibilityAddTraits(.isHeader)
            }
            _VariadicView.Tree(SettingsDividedRows()) { content }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, settingsCardInset)
        }
        .padding(.top, 18)
    }
}

private struct SettingsDividedRows: _VariadicView_MultiViewRoot {
    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let lastID = children.last?.id
        VStack(alignment: .leading, spacing: 0) {
            ForEach(children) { child in
                child
                if child.id != lastID {
                    Divider().padding(.leading, 16)
                }
            }
        }
    }
}

/// Base row: title (+ optional caption beneath) on the left, a trailing control.
struct SettingsRow<Control: View>: View {
    let title: String
    var caption: String?
    var titleTint: Color?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(titleTint ?? .primary)
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control.layoutPriority(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsValueRow: View {
    let title: String
    var caption: String?
    let value: String

    var body: some View {
        SettingsRow(title: title, caption: caption) {
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityLabel("\(title), \(value)")
    }
}

struct SettingsToggleRow: View {
    let title: String
    var caption: String?
    var isEnabled = true
    private let getValue: () -> Bool
    private let setValue: (Bool) -> Void

    init(_ title: String, caption: String? = nil, isOn: Binding<Bool>, isEnabled: Bool = true) {
        self.title = title
        self.caption = caption
        self.isEnabled = isEnabled
        getValue = { isOn.wrappedValue }
        setValue = { isOn.wrappedValue = $0 }
    }

    /// Get/set variant for stores whose "enabled" flag is not a plain `Binding`.
    init(_ title: String, caption: String? = nil, isEnabled: Bool = true,
         get: @escaping () -> Bool, set: @escaping (Bool) -> Void) {
        self.title = title
        self.caption = caption
        self.isEnabled = isEnabled
        getValue = get
        setValue = set
    }

    var body: some View {
        // Written as closure literals (not forwarded parameters) so `Binding.init`'s
        // `@_inheritActorContext` picks up `body`'s MainActor isolation here, instead
        // of requiring `getValue`/`setValue` to be independently `@Sendable`.
        SettingsRow(title: title, caption: caption) {
            Toggle("", isOn: Binding(get: { getValue() }, set: { setValue($0) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(!isEnabled)
        }
    }
}

struct SettingsPickerRow<SelectionValue: Hashable, Options: View>: View {
    let title: String
    var caption: String?
    let selection: Binding<SelectionValue>
    @ViewBuilder var options: Options

    var body: some View {
        SettingsRow(title: title, caption: caption) {
            Picker("", selection: selection) { options }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
        }
    }
}

/// A real bordered action button — not a bare colored link — so it reads as
/// something to click rather than as inline text.
struct SettingsButtonRow: View {
    let title: String
    var systemImage: String?
    var caption: String?
    var role: ButtonRole?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(role: role, action: action) {
                Group {
                    if let systemImage {
                        Label(title, systemImage: systemImage)
                    } else {
                        Text(title)
                    }
                }
                .fixedSize()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(role == .destructive ? .red : .accentColor)
            .disabled(!isEnabled)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
    }
}

struct SettingsLinkRow: View {
    let title: String
    let systemImage: String
    let destination: URL

    var body: some View {
        HStack(spacing: 12) {
            Link(destination: destination) {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
    }
}

struct SettingsInfoRow: View {
    let text: String
    var systemImage: String
    var tint: Color?

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.callout)
        .foregroundStyle(tint ?? Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

/// Standalone explanatory paragraph between sections — never inside a box.
struct SettingsNote: View {
    let text: String
    var tint: Color?

    init(_ text: String, tint: Color? = nil) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tint ?? Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 2)
    }
}

// MARK: - Provider detail header

struct SettingsProviderCard<Trailing: View>: View {
    let provider: UsageProvider
    let statusLine: String
    var isOn: Bool
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((provider == .codex ? Color.green : Color.orange).gradient)
                .frame(width: 30, height: 30)
                .overlay(
                    ProviderLogo(provider: provider, size: 16)
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.title).font(.headline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(provider.title), \(isOn ? "on" : "off"). \(statusLine)")
    }
}
