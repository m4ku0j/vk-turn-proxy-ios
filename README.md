# VK Turn Proxy — iOS

iOS порт [vk-turn-proxy-android](https://github.com/MYSOREZ/vk-turn-proxy-android). Запускает vk-turn-proxy client и пробрасывает WireGuard трафик через TURN-серверы VK Звонков.

## Структура

```
VKTurnProxy/
├── App/
│   ├── VKTurnProxyApp.swift
│   └── ContentView.swift
├── Views/
│   ├── MainView.swift        ← главный экран
│   ├── LogConsoleView.swift  ← лог-консоль
│   └── SettingsView.swift    ← SSH управление сервером
├── Services/
│   ├── ProxyService.swift    ← запуск бинарника
│   └── SSHManager.swift      ← SSH через NMSSH
├── Models/
│   └── ProxySettings.swift   ← @AppStorage настройки
└── Resources/
    └── vkturn-client         ← ← СЮДА КЛАДЁШЬ БИНАРНИК
```

## Сборка в Xcode

**1. Новый проект:** App → SwiftUI → Swift

**2. Добавь NMSSH через SPM:**
```
File → Add Package Dependencies
URL: https://github.com/NMSSH/NMSSH.git
```

**3.** Скопируй все .swift файлы из этой папки в проект.

**4. Бинарник клиента:**
Скачай: https://github.com/cacggghp/vk-turn-proxy/releases/download/v1.1.1/client-android-arm64
Переименуй в `vkturn-client`, добавь в Xcode → Target Membership ✓

**5. Подпись:** любой Apple ID (для сайдлоада через AltStore/Sideloadly)

## Использование

1. Peer: `192.145.28.186:56000`
2. VK Link: `https://vk.com/call/join/L9nYQRPzbxEsPoFnVXYSIgMYJXS7dFlmwW2rVChL9Sc`
3. UDP: ON, Потоки: 8
4. ЗАПУСТИТЬ ПРОКСИ → дождаться `Established DTLS connection!`
5. WireGuard: Endpoint = `127.0.0.1:9000`, MTU = 1280, добавить VKTurnProxy в исключения

> ⚠️ Subprocess работает при сайдлоаде. Для App Store нужен Network Extension.
