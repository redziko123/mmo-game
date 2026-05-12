# 2D MMO – Godot 4 + Python

Prosta gra MMO napisana w Godot 4 (klient) i Python (serwer WebSocket).

## Struktura projektu

```
gd1/
├── client/              ← Projekt Godot 4
│   ├── project.godot
│   ├── scripts/
│   │   ├── GameData.gd        – singleton: dane gracza
│   │   ├── NetworkManager.gd  – singleton: połączenie WebSocket
│   │   ├── Main.gd            – główna scena gry
│   │   ├── Player.gd          – węzeł gracza (lokalny i zdalny)
│   │   └── LoginScreen.gd     – ekran logowania
│   ├── scenes/          ← stwórz w edytorze Godot
│   └── assets/
│       └── sprites/
├── server/              ← Serwer Python
│   ├── server.py
│   └── requirements.txt
└── .vscode/
    ├── launch.json
    └── settings.json
```

## Uruchomienie serwera

```powershell
cd server
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python server.py
```

## Uruchomienie klienta

1. Otwórz folder `client/` w **Godot 4**
2. Utwórz sceny w edytorze (patrz niżej)
3. Naciśnij **F5** lub ▶ Play

## Tworzenie scen w Godot (krok po kroku)

### Scena: `LoginScreen.tscn`

```
Control (skrypt: LoginScreen.gd)
└── VBox (VBoxContainer, anchor: Center)
    ├── Label ("Podaj nazwę gracza:")
    ├── NameInput (LineEdit)
    ├── ColorPickerButton
    ├── JoinButton (Button, tekst: "Dołącz do gry")
    └── ErrorLabel (Label, kolor: czerwony)
```

→ Ustaw jako główną scenę w Project Settings.

### Scena: `Player.tscn`

```
CharacterBody2D (skrypt: Player.gd)
├── CollisionShape2D (RectangleShape2D, 32x32)
├── ColorRect (kolor tymczasowy, rozmiar 32x32)
└── Label (tekst: "Gracz", pozycja: -16, -40)
```

### Scena: `Main.tscn`

```
Node2D (skrypt: Main.gd)
├── Players (Node2D – kontener dla graczy)
├── TileMap (opcjonalnie – mapa świata)
└── UI (CanvasLayer)
    └── ChatPanel (Panel, anchor: BottomLeft)
        ├── ChatLog (RichTextLabel, BBCode: ON)
        └── ChatInput (LineEdit)
```

## Funkcje

| Funkcja                              | Status |
| ------------------------------------ | ------ |
| Wieloosobowość WebSocket             | ✅     |
| Ruch gracza (WASD / strzałki)        | ✅     |
| Interpolacja pozycji zdalnych graczy | ✅     |
| Czat globalny                        | ✅     |
| Wybór nazwy i koloru                 | ✅     |
| Dołączanie/opuszczanie graczy        | ✅     |

## Kolejne kroki

- [ ] Mapa z TileMap i kolizjami
- [ ] System HP i walka
- [ ] Inwentarz i przedmioty
- [ ] Baza danych (SQLite/PostgreSQL)
- [ ] Autoryzacja (login/hasło)
- [ ] Wrogowie (AI)
