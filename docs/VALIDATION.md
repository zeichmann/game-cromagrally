# Weryfikacja M1 — 2026-11-15

Środowisko: Windows x64, oficjalny Godot 4.7.2 (`ed1daf0bf`), fizyka 60 Hz. Kontrola obrazu: renderer Compatibility, Intel Iris Xe.

| Sprawdzenie | Wynik |
|---|---|
| Reguły, kierunek bramek, kolejność, brak skrótów, ranking i odzyskiwanie pojazdu | PASS — 133 sprawdzenia |
| Pauza, współdzielona symulacja, niezależne widoki, restart, odłączenie urządzenia i wyniki | PASS — 32 sprawdzenia |
| Pełny wyścig obu typów pojazdów, sześciu AI, trzy uporządkowane okrążenia, cztery widoki | PASS — wszyscy ukończyli; ostatni w 111,02 s czasu symulacji |
| Pierwsze uruchomienie `Run.cmd` z czystej kopii źródeł bez `.godot` | PASS — automatyczny import i uruchomienie, kod wyjścia 0 |
| Podgląd renderowanej gry | Sprawdzono jazdę i cztery równoczesne kamery z HUD-em |
| Cztery fizyczne kontrolery | Nie sprawdzano sprzętowo; routing urządzeń i reakcja na rozłączenie sprawdzone w testach sesji |

Polecenia do powtórzenia testów znajdują się w README. Test pełnego wyścigu wykonano bez przyspieszania czasu i bez podmieniania reguł ani teleportowania AI do mety.

Nie wykonano jeszcze testów LAN, Steam, finalnej oprawy ani cząsteczek i animacji szkieletowych na GPU — te elementy nie są częścią prototypu M1. Wyniki nie są oceną praw do komercyjnej publikacji.
