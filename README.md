# Windward Circuit — Stylized Art Preview

**Podstawy jazdy, 2026-11-18:** płynny skręt i hamowanie przed cofaniem, sześć profili nawierzchni, kamera sprawdzająca przeszkody, przestrzenne dźwięki napędu, opon i uderzeń oraz AI wybierające pas mijania. Doszły bezpieczny powrót obok innych aut, czasy okrążeń i ostrzeżenia HUD-u, ustawienia klawiszy, czułości, dźwięku i przeciwników oraz osobne wybory pojazdu i postaci lokalnych graczy. Leśne zakręty są łagodniejsze i mają osiem znaków kierunku. [Zmiany, natywne ujęcia, testy i pomiary](docs/driving-foundation/README.md).

**Postacie v5, 2026-11-17:** warstwowe oczy z zagłębioną brązową tęczówką i rogówką odbijającą światła, cieńsze powieki oraz nowe tekstury skóry z porami i pigmentem. Spokojniejszy uśmiech, pełniejsze policzki Świnki i powieki reagujące na radość. Spojrzenie, mruganie, mimika i skórkowanie pozostają na GPU. [Rzeczywiste ujęcia, porównanie z oryginałami Akademii Oli i wyniki](docs/academy-v5/README.md).

**Nowy przyrost:** zakręt przy herbaciarni z giętym dachem, wielkim rozgałęzionym dębem, kamiennym mostem, kładką i strumieniem odpływającym do morza. Taras ma stoliki, dzbanki i gości; liście, szyld i nurt poruszają się na GPU, podobnie jak para i spadające liście. **Run-teahouse.cmd** pokazuje cztery ujęcia tego miejsca. [Rzeczywiste zrzuty, zasoby i pomiary](docs/tea-bend/README.md).

Niezależna zręcznościowa gra wyścigowa w Godot 4.7.2. Cały tor otacza teraz bajkowa wyspa: kwiecista wioska, gaj z glicynią, wodospad przy kamiennym moście, zamkowe wzgórze, ogrody i przystań. Menu pokazuje wybraną postać i pojazd w podglądzie 3D. Szczegóły, zasoby i rzeczywiste widoki: [bajkowa wyspa](docs/fairytale-assets/README.md). To przyrost M2; pełna zawartość gry pozostaje w produkcji.

## Uruchomienie

W Windows kliknij **Run.cmd**. Gra i wszystkie podglądy uruchamiają się domyślnie na pełnym ekranie. **Run-tour.cmd** uruchamia zapętlony podgląd szesnastu miejsc, zaczynając od herbaciarni; **Run-teahouse.cmd** zapętla cztery ujęcia samego zakrętu, drzewa, strumienia i tarasu. **Esc** przywraca menu gry. W tej kopii roboczej jest już lokalny, oficjalny silnik w `runtime/Godot.exe`; nie wymaga instalacji. Katalog `runtime` jest pomijany przez Git.

Domyślny renderer to Forward+, z profilem High; wybór jest zapisywany w ustawieniach. Menu pozwala wybrać High, Balanced lub Performance. High używa MSAA 4×, SSAO, SSIL i miękkich cieni do 160 m. Balanced używa FXAA, skalowania FSR 0,75 i cieni do 100 m. Performance używa FXAA, skali 0,50, istniejących lżejszych siatek roślin i lekkiego cienia kontaktowego pod autem zamiast dynamicznych cieni otoczenia. Obniżona skala działa również przy jednym graczu. FSR jest używane przy skali renderowania poniżej 1,0. Skala uwzględnia fizyczne rozmiary okna, więc High nie renderuje dodatkowo ponad jego rozdzielczość. **Run-light.cmd** wybiera Forward+ i profil Performance. Animacja wymaga RenderingDevice (na tym Windows używa Vulkan); OpenGL Compatibility nie jest obsługiwany. [Aktualne pomiary podstaw jazdy](docs/driving-foundation/README.md) oraz [wcześniejsze raporty oprawy](docs/GRAPHICS_VALIDATION.md).

Początkowy ekran „Preparing Windward Island…” renderuje warianty materiałów i trzech profili jakości przed rozpoczęciem jazdy. Obejmuje dwadzieścia widoków, pojazdy, mieszkańców oraz emitery cząsteczek. Przy pierwszym uruchomieniu albo po zmianie sterownika może trwać dłużej; przygotowanie odbywa się przed menu lub podglądem wyspy.

Po pobraniu samych źródeł zainstaluj [Godot 4.7.2 Standard](https://godotengine.org/download/windows/) i otwórz `project.godot` albo umieść oficjalny plik wykonywalny Windows x64 pod nazwą `runtime/Godot.exe`. W pustym `runtime/_sc_` można włączyć przenośne ustawienia edytora. Uruchomienie silnika może wymagać pierwszego importu projektu:

```powershell
godot --headless --editor --single-threaded-scene --path . --import --quit
godot --path .
```

Projekt nie odczytuje żadnych plików z katalogu nadrzędnego. Można przenieść cały `IndependentRacer` poza poprzednie repozytorium.

## Co działa

- Jeden nowy zamknięty tor na wyspie, z przewyższeniami i szesnastoma punktami kontrolnymi.
- Zmienna szerokość jezdni, brukowane uliczki i plac, leśna ziemia, drewniane mosty oraz kamienne odcinki zamku. Krótszy przejazd grotą łączy się z główną drogą między legalnymi bramkami.
- 41 odnawiających się nasion wiatru. Trzy ładunki zasilają jeden dopalacz; można zachować maksymalnie dziewięć. Sekret groty przyznaje trzy ładunki raz na wyścig. Bród zmniejsza przyczepność, a rampa wybija szybki pojazd.
- Dwa własne pojazdy: lekki wózek żaglowy i cięższy pojazd z kołem zamachowym.
- Dynamiczne podwozia Jolt: masa 280/380 kg, tarcie, odbicie i obrót po uderzeniu. Fizyczny teren całej wyspy podtrzymuje samochód po zjechaniu z asfaltu. [Opis, źródła algorytmów i testy](docs/collisions/README.md).
- Statyczne collidery budynków, murów, płotów, pni, skał i znaków, niezależne od odległości renderowania oraz profilu grafiki. Bramy i grota zachowują otwarte przejazdy. Zderzenia aut są sprawdzane z aktywnym sterowaniem w rzeczywistej scenie wyścigu. [Ujęcia i testy kolizji otoczenia](docs/scenery-collisions/README.md).
- Żabol i Świnka z Akademii Oli jako kierowcy 3D; wybór postaci jest niezależny od pojazdu. W demonstracji występują obie postacie.
- Sześć pojazdów w wyścigu; niewykorzystane miejsca prowadzi AI.
- Trzy okrążenia, kolejność na trasie, pomiar czasu, wyniki i lokalny rekord.
- Jeden do czterech lokalnych graczy; jedna klawiatura i osobny kontroler dla każdego kolejnego gracza albo same kontrolery.
- Oddzielne kamery i HUD dla każdego gracza, we wspólnym świecie fizycznym.
- Pauza, restart, powrót do menu, odzyskiwanie pojazdu i pauza po odłączeniu przypisanego kontrolera.
- Kamera z kontrolą prześwitu, także podczas cofania; płynny powrót do zwykłej odległości po minięciu przeszkody.
- Przestrzenne odgłosy napędu, toczenia i poślizgu oraz pojedyncze efekty uderzenia, lądowania, dopalacza i zbierania nasion.
- Poziomy przeciwników Easy/Normal/Hard; AI sprawdza zajętość pasów i wolne przejazdy zamiast wyłącznie celować w środek drogi.
- `SETTINGS / LOCAL CREW`: zmiana klawiszy, czułości, głośności, efektów kamery i osobne pojazdy oraz postacie czterech graczy. Wybory załogi obowiązują od następnego startu.
- Tryb demonstracyjny czterech widoków sterowanych przez AI, dostępny bez kontrolerów.

## Nowa oprawa

- [Zakręt przy herbaciarni](docs/tea-bend/README.md): cztery osobne modele z LOD, pojedyncze dachówki, wykusz, zamknięte poddasze, drzwi z okuciami, kołyszący się szyld na wsporniku, taras ze stolikami i zastawą oraz dąb z 4 680 liśćmi. Koryto strumienia jest wycięte w terenie i przykryte gęstszą siatką brzegów. Droga ma stopniowe zwężenie i most, a piesza kładka prowadzi pod drzewo. Nowa tekstura kory ma natywne 1254×1254 px.
- [Bajkowy kierunek](docs/enchanted-island/README.md): piekarnia w pniu, przejazd pod starym drzewem, zaokrąglone i asymetryczne domki, skalne tarasy zamku, dom rybaka na palach, cieplejsze światło i nieregularne skupiska roślin. Nowa malarska łąka ma 1254×1254 px; obraz zachowano w natywnym rozmiarze.
- Dwa modele pojazdów z gładkimi przekrojami, obręczami i szprychami, bieżnikiem opon, nitami, reflektorami, żaglem lub osłoną koła zamachowego.
- Kierowcy używają siatek `academy_v5`: osobna anatomia według portretów Akademii Oli, zagłębione oczy z teksturowaną tęczówką i przezroczystą rogówką, skóra o zmiennym pigmencie i szorstkości, zamykane powieki oraz uśmiech sprzężony z powiekami. Pozy, skórkowanie i mimika są na GPU. Żagiel odsłania kierowcę. Królik i mysz zachowują twarze, stroje i akcesoria z v3. Pochodzenie, rzeczywiste ujęcia oraz odbudowa: [CHARACTERS.md](docs/CHARACTERS.md).
- Oprócz wcześniejszych materiałów dodano łąkę, naturalny wapień, liście, kwiaty koron i drobny piasek **1254×1254 px** oraz panoramę nieba **1774×887 px**. To natywne rozmiary, bez powiększania. Import wszystkich PNG w assets/textures ma włączone mipmapy, a materiały powierzchni filtrują anizotropowo.
- Sześć odcinków pełnego okrążenia i **57 modeli otoczenia i mieszkańców**, większe z LOD. Doszły poczta, pracownia i herbaciarnia z nadwieszonymi piętrami, balkonami, bocznymi oknami, szyldami i kwiatami, a także grota, wielkie paprocie, omszałe skały, grzyby i żuraw portowy. MultiMesh ma mniejsze grupy przestrzenne, a teren i budynki przesłaniają dalszą geometrię.
- Króliki i myszy na chodnikach i rynku, kibice przy trasie, cztery koty, siedem kaczek i czternaście mew. Sześć ważonych części na zwierzę porusza shader GPU: chód, machanie, obrót głowy, ogon, skrzydła i kołysanie na wodzie. Banki jakości zmniejszają liczbę odległych postaci bez przemieszczania zachowanych instancji.
- Własne shadery wody z kolorami zależnymi od głębokości, pianą i analitycznymi kontaktami łodzi, nieba z chmurami, terenu, żagla i roślin poruszanych wiatrem. Oświetlenie ma ciepłe słońce, lawendowe wypełnienie cieni i mapowanie tonów ACES; High dodaje SSIL.
- Pozy kierowców, obrót i skręt kół, śmigła, przechył nadwozia oraz wiatrak są obliczane na GPU. Wspólny bufor 32×8 RGBA32F powstaje raz na klatkę i obsługuje wszystkie kamery. CPU wysyła sześć rekordów sterowania; nie odczytuje wyników animacji.
- Kurz, mgiełka kaskady, fontanny, dym, płatki, leśne świetliki, rozbryzgi brodu, smuga dopalacza i liście za pojazdem korzystają z `GPUParticles3D`. Pozostałe ruchy dekoracyjne korzystają ze wspólnego zegara GPU, zatrzymywanego podczas pauzy. Cząsteczki nie wpływają na wynik wyścigu.
- Pięć własnych ośmiosekundowych pętli dźwiękowych: las, potok, przystań, rynek i pracownia. Siedem przestrzennych źródeł, w tym nowy strumień przy herbaciarni, ma ograniczony zasięg; podzielony ekran korzysta z jednego słuchacza. `M` wycisza dźwięk.
- Poprawiona orientacja i rozmieszczenie krawężników, wysokości roślin zgodne z siatką terenu oraz kontakt pojazdów bez wjeżdżania na cudzy dach. AI odzyskuje ostatnią legalną bramkę, jeśli zderzenie wypchnie je poza punkt kontrolny.

Prompty i pochodzenie: [tęczówka i skóra postaci v5](docs/academy-v5/TEXTURE_PROMPTS.json), [nocny zestaw tekstur](docs/fairytale-assets/NIGHT_PROMPTS.json), [wcześniejsze tekstury wyspy](docs/fairytale-assets/PROMPTS.json), [PROVENANCE.md](docs/PROVENANCE.md). Zrzuty i pomiary: [GRAPHICS_VALIDATION.md](docs/GRAPHICS_VALIDATION.md).

## Sterowanie

| Urządzenie | Jazda | Hamulec | Dopalacz | Powrót na tor | Pauza |
|---|---|---|---|---|---|
| Klawiatura | WASD / strzałki | Spacja | Shift | R | Esc |
| Kontroler | Lewy drążek, RT / A; LT — wstecz | X | B | Y | Start |

Menu wymaga rzeczywistych kontrolerów dla wybranej liczby graczy. Demonstracja pokazuje cztery kamery, ale wszystkie pojazdy prowadzi AI. Wyścigi demonstracyjne nie zapisują rekordów.

Rekord jest przechowywany w `user://m1_records.json`, czyli w katalogu danych użytkownika Godot. Uszkodzony lub niezgodny zapis jest ignorowany.

Ustawienia są w osobnym `user://race_settings.json`. Zmiana zajętego klawisza zamienia przypisania dwóch akcji. Domyślne strzałki pozostają alternatywą dla WASD. Zmiana konfiguracji klawiatury aktualizuje podpowiedzi menu i dopalacza; kontrolery zachowują standardowe przypisania z tabeli.

## Pochodzenie i publikacja

Skrypty gry, matematyczny kształt toru, modele pojazdów i scenerii, tekstury otoczenia, układ menu i syntetyczne sygnały dźwiękowe powstały dla tego projektu. Postacie przeniesiono i zaadaptowano z lokalnej Akademii Oli na prośbę użytkownika; zachowują jej pochodzenie i własność artworku. Nie zaimportowano kodu, shaderów, map, modeli, tekstur ani dźwięków z Cro-Mag Rally lub jego zmodyfikowanego forka. Szczegóły: [PROVENANCE.md](docs/PROVENANCE.md).

Godot jest udostępniany na MIT i dopuszcza gry komercyjne, także z zamkniętym kodem. Informacje silnika i bibliotek są w [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) oraz [GODOT_NOTICES.json](docs/GODOT_NOTICES.json). Nie nadano nowej implementacji publicznej licencji open source; decyzja o jej udostępnianiu pozostaje do podjęcia przez właściciela projektu.

Oddzielne źródła i zapis pochodzenia ułatwiają przygotowanie niezależnej gry. Nie stanowią potwierdzenia praw do marki ani formalnego audytu prawnego. Nazwa „Windward Circuit” jest robocza. Ograniczenia licencji poprzedniego forka pozostają w mocy dla jego plików.

## Testy

W poniższych poleceniach `godot` oznacza oficjalny silnik 4.7.2; na Windows wygodnie użyć jego wariantu konsolowego.

```powershell
godot --headless --path . --script res://tests/test_rules.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_vehicle_physics.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_offroad_physics.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_world_collisions.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_handling.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_driving_foundation.gd
godot --headless --path . --script res://tests/test_art.gd
godot --headless --path . --script res://tests/test_portrait_assets.gd
godot --headless --path . --script res://tests/test_organic_assets.gd
godot --path . --script res://tests/test_academy_faces.gd
godot --headless --path . --script res://tests/test_environment.gd
godot --headless --path . --script res://tests/test_living.gd
godot --headless --path . --script res://tests/test_tea_bend.gd
godot --path . --script res://tests/test_gpu_motion.gd
godot --path . --script res://tests/test_gpu_skin.gd
godot --path . --script res://tests/test_gpu_life.gd
godot --path . --script res://tests/test_tea_gpu.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_session.gd
godot --headless --path . --fixed-fps 60 -- --race-test
```

Test reguł obejmuje bramki, okrążenia, orientację geometrii i oddzielne sygnały sterowania. Test grafiki sprawdza powierzchnie skórkowanej siatki, wagi, alfa liści, wysokości terenu, krawężniki i płaskie kontakty pojazdów. Test sesji obejmuje podgląd menu, widoki, pauzę, odłączenie urządzenia, restart i wyniki. Pełny wyścig przeprowadza sześć AI przez trzy legalne okrążenia, przy standardowym kroku fizyki 1/60 s i czterech widokach. Kończy się błędem, jeśli pojazdy nie dojadą w 240 sekund czasu symulacji.

`tests/test_handling.gd` mierzy reakcję skrętu, centrowanie, przyspieszenie, hamowanie przed cofaniem i zatrzymanie. `tests/test_driving_foundation.gd` sprawdza fizyczną przeszkodę za kamerą, ruch wstecz, mijanie i blokadę pasów, zajęte miejsce powrotu, nawierzchnie, zapis ustawień i osobne wybory graczy. `godot --path . --fullscreen --fixed-fps 60 --script tools/review_driving_foundation.gd` dodaje natywny obraz, rzeczywisty dźwięk uderzenia i kontrolę interfejsu ustawień.

Nie używaj `--time-scale` do końcowej weryfikacji fizyki, bo zmienia krok symulacji. Dla podglądu czterech widoków: `Run.cmd -- --demo-four`.

Pomiary rzeczywistego renderera, bez blokady FPS, ze zrzutami z samego silnika:

```powershell
godot --path . --script res://tools/benchmark_art.gd -- --menu --high
godot --path . --script res://tools/benchmark_art.gd -- --high
godot --path . --script res://tools/benchmark_art.gd -- --high --circuit
godot --path . --script res://tools/benchmark_art.gd -- --four
godot --path . --script res://tools/benchmark_art.gd -- --four --performance
```

Wyniki JSON i obrazy trafiają do pomijanego przez Git `build/art-review/`. Przygotowanie grafiki, pierwsze dwie klatki i pięć sekund rozgrzewki nie wchodzą do statystyki. Odczyt obrazu i zapis PNG są wyłączone z mierzonego czasu. Renderer sprawdza rzeczywisty układ krawężników i banków instancji otoczenia. Zwykła próbka obejmuje około 12 sekund pomiaru jazdy, a `--circuit` około 40 sekund i wyniki sześciu odcinków. Opcja `--cold` pomija przygotowanie, pozwalając odtworzyć koszt pierwszego użycia wariantów shaderów. Bieżące liczby dla Iris Xe, surowe pliki JSON i porównanie z poprzednią wersją są w [GRAPHICS_VALIDATION.md](docs/GRAPHICS_VALIDATION.md).

## Granice etapu

To rozwijana wersja nowej oprawy. Całe okrążenie ma teraz odrębne odcinki i dekoracje, ale nadal wymaga dalszego dopracowania oraz optymalizacji. Nie ma jeszcze uzbrojenia, pozostałych trybów, LAN, pucharów, pełnego zestawu animacji i mimiki postaci, wszystkich efektów wyposażenia, produkcyjnego pakietu tekstur 2K/4K ani integracji Steam. Nowe modele kierowców są wdrożone; ich podobieństwo do referencji pozostaje do oceny użytkownika. Ostateczne wymagania sprzętowe i wydajność w 1080p pozostają do sprawdzenia.

Pełny zakres pozostaje: siedem trybów, dziewięć tras, osiem aren, dziesięć pojazdów lądowych i jeden podwodny, dwie postacie, dziewięć broni i trzy wzmocnienia, lokalnie czterech i w LAN sześciu graczy oraz trzy puchary. Kolejne etapy: dopracowany wycinek gry, cały pakiet rozgrywki, LAN, pełna zawartość i wydanie sklepowe. M1 nie zastępuje tego zakresu.
