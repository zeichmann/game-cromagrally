# Pochodzenie plików prototypu

Data rozpoczęcia: 2026-11-15. Silnik: Godot 4.7.2 Standard, oficjalny Windows x64.

| Element | Źródło |
|---|---|
| `scripts/progress.gd` | Nowe reguły kolejnych bramek, okrążeń i rankingu |
| `scripts/track.gd` | Nowa analityczna krzywa, własne siatki drogi i wyspy oraz rekwizyty z brył |
| `scripts/vehicle.gd` | Nowy kontroler arcade, AI i dekoracyjny emiter kurzu GPU |
| `scripts/chase_camera.gd`, `race_traffic.gd`, `race_preferences.gd`, `settings_panel.gd`, `race_signs.gd` | Własna kontrola prześwitu kamery przez zapytania do fizyki Godot, planowanie pasów AI, walidowany zapis preferencji, interfejs ustawień i autorskie znaki zakrętów. Bez nowego kodu i zasobów osób trzecich |
| `scripts/driving_audio.gd`, `tools/build_driving_audio.py`, `assets/audio/driving/` | Osiem własnych dźwięków z deterministycznej syntezy harmonicznej i szumu, bez nagrań i sampli. Dwie pętle napędu, opony, toczenie, kontakt, lądowanie, dopalacz i nasiono; parametry oraz SHA-256 w manifeście katalogu |
| `scripts/quality_mesh.gd`, `shaders/ground_shadow.gdshader` | Własny wybór wcześniej wygenerowanych indeksów LOD roślin przez API `ImporterMesh` Godot i analityczny miękki cień pod autem w Performance. Kopie zachowują oryginalne materiały i rozmieszczenie; siatki źródłowe i collidery pozostają wspólne z High |
| `scripts/vehicle_contacts.gd` | Własna konfiguracja dynamicznych podwozi: masa, kształt, tarcie, odbicie i CCD. Wykrywanie kontaktów i rozwiązywanie impulsów realizuje publiczny Jolt wbudowany w używany silnik; źródła i wyniki w `collisions/README.md`. Zachowany testowy obrys SAT nie przesuwa już pojazdów |
| Fizyczny teren wyspy | Collider statyczny z dokładnie tych samych trójkątów co własna siatka terenu `scripts/scenery_art.gd`; bez zewnętrznych zasobów |
| `scripts/world_collisions.gd` | Własny wybór stałych części istniejących modeli, współdzielone siatki kolizji i rozmieszczenie statycznych brył. Kontakty pojazdów z budynkami i przeszkodami rozwiązuje Jolt wbudowany w Godot. Bez nowych zasobów zewnętrznych; test rzeczywistej sceny oraz natywne ujęcia w `scenery-collisions/README.md` |
| `scripts/art.gd`, `vehicle_art.gd` | Nowe materiały i scalane modele dwóch pojazdów, koła, żagiel i detale |
| `scripts/driver_art.gd`, `academy_rig.gd` | Nowy wspólny rig i animacja kierowców Akademii Oli; sześć kości i skórkowane siatki |
| `assets/characters/` | Model Żabola z lokalnej Akademii Oli oraz adaptacje do wyścigów: Żabol i Świnka. Dokładne źródła, zmiany, hashe i odbudowa w `CHARACTERS.md` i `CHARACTER_ASSET_MANIFEST.json` |
| `tools/academy_driver_builder.gd` | Nowa adaptacja geometrii do kokpitu, selekcja części, materiały, siatka Świnki, wagi szkieletu i LOD |
| `scripts/scenery_art.gd`, `fairytale_world.gd` | Nowy teren z rzeką i wzgórzami, roślinność, sześć odcinków i własna architektura całej wyspy |
| `tools/fairy_asset_builder.gd`, `botanical_builder.gd`, `architecture_builder.gd`, `sky_asset_builder.gd`, `enchanted_builder.gd`, `living_asset_builder.gd`, `resident_builder.gd`, `assets/fairytale/` | 57 modeli otoczenia i mieszkańców utworzonych w kodzie, zapisanych z LOD; bez modeli z poprzedniej gry |
| `scripts/palette_mesh.gd`, `tools/build_render_drivers.gd` | Łączenie materiałów i kopie sześciu istniejących siatek kierowców. Pozycje i wpływy kości są sprawdzane względem zachowanych źródeł; nie zmieniono odrzuconego wyglądu postaci |
| `scripts/waterfall_path.gd`, `waterfall_garden.gd`, `fountain_flow.gd` | Nowa geometria źródła i kaskady oraz dekoracyjna symulacja wody na GPU |
| `scripts/island_tour.gd`, `Run-tour.cmd` | Czternaście płynnych ujęć rzeczywistego świata gry i powrót do menu klawiszem Esc |
| `scripts/storybook_atmosphere.gd`, `shaders/storybook_*.gdshader` | Własne emitery GPU dymu i płatków oraz geometryczny, przezroczysty łuk tęczy; bez tekstur cząsteczek z zewnętrznych źródeł |
| `scripts/gpu_motion.gd`, `gpu_motion_device.gd`, `shaders/gpu_motion.glsl`, `gpu_motion.gdshaderinc`, `gpu_clock.gdshaderinc` | Nowe obliczanie póz i stanu animacji na GPU, współdzielony atlas macierzy, deformacja siatek i zatrzymywany zegar shaderów |
| `tests/driver_pose_reference.gd` | Zachowana dotychczasowa poza CPU wyłącznie jako odniesienie testowe; nie jest ładowana przez grę |
| `scripts/graphics_warmup.gd` | Przygotowanie rzeczywistych wariantów renderowania trzech profili za początkowym ekranem ładowania |
| `shaders/` | Nowe shadery wyspy, wody z głębokością, nieba, roślin, żagla, drewna i gumy |
| `scripts/main.gd` | Nowa obsługa sesji, współdzielonego świata, kamer, menu i zapisu |
| `scripts/hud.gd` | Nowy interfejs i minimapa obliczana z kształtu nowego toru |
| Sygnały dźwiękowe | Synteza sinusoidalna w nowym kodzie, bez próbek audio |
| `tools/storybook_driver_builder.gd`, `assets/characters/storybook_v2/` | Nowa lokalna rzeźba głów i strojów według referencji Akademii Oli; osobna anatomia każdej postaci, sześć kości i trzy warianty szczegółowości. Nie importowano siatki starszego modelu. Projekty postaci zachowują pochodzenie z Akademii Oli |
| `tools/portrait_geometry.gd`, `portrait_character_builder.gd`, `assets/characters/portrait_v3/` | Zachowana trzecia wersja: własna jawna topologia twarzy, dopasowane oczy, profilowany ryjek z kieszeniami nozdrzy i nowe stroje. Wspólne funkcje brył odziedziczone z poprzedniego narzędzia. Referencje projektów z Akademii Oli; bez zewnętrznych modeli i nowych bitmap. Obrazy, źródła i SHA-256 w `portraits-v3/` |
| `tools/academy_face_geometry.gd`, `academy_character_builder.gd`, `assets/characters/academy_v4/`, `shaders/academy_face.gdshaderinc` | Zachowana czwarta wersja kierowców: własne modele według oryginalnych portretów Akademii Oli, jawna topologia, poprawione proporcje, cele zamknięcia powiek i normalnych oraz ruch spojrzenia i uśmiechu na GPU. Konstrukcja strojów wykorzystuje wcześniejsze własne narzędzie v3. Bez zewnętrznych modeli, nowych bitmap i wysyłania artworku. Natywne obrazy i SHA-256 w `academy-v4/` |
| `tools/organic_face_geometry.gd`, `organic_character_builder.gd`, `assets/characters/academy_v5/`, `shaders/academy_cornea.gdshader`, `driver_deformation.gdshaderinc` | Aktywna piąta wersja: własna geometria rozwijająca v4, zagłębione oczy z osobną rogówką, cieńsze powieki, pełniejsze policzki oraz wspólna deformacja twarzy i skórkowanie GPU. Projekty postaci według zachowanych oryginałów Akademii Oli. Bez zewnętrznych modeli i wysyłania portretów do usług 3D; natywne obrazy i hashe w `academy-v5/` |
| `assets/textures/academy_{iris,frog_skin,pig_skin}_v5.png` | Trzy nowe oryginalne materiały z wbudowanego image_gen, wyłącznie opisy tekstowe. Natywne PNG 1254×1254, skopiowane bez skalowania i edycji. Dokładne prompty i ścieżki w `academy-v5/TEXTURE_PROMPTS.json`, SHA-256 w manifeście przyrostu |
| `tools/portrait_resident_builder.gd`, `build_portrait_residents.gd`, `assets/fairytale/resident_{rabbit,mouse}.res` | Nowe oryginalne modele królika i myszy: twarze, powieki, stroje i akcesoria, z zachowaniem sześciu grup animacji GPU. Pozostałe trzy gatunki zachowane |
| `scripts/living_districts.gd`, `village_life.gd`, `shaders/resident_motion.gdshaderinc` | Własne rozmieszczenie ulic, groty, mostu i mieszkańców oraz analityczna animacja stawów w GPU |
| `tools/tea_asset_builder.gd`, `assets/tea_bend/` | Cztery nowe oryginalne modele: herbaciarnia, wielki dąb z pojedynczymi liśćmi, taras i szyld. Geometria, UV i LOD tworzone lokalnie, bez zewnętrznych modeli |
| `scripts/tea_bend.gd`, `tea_bend_layout.gd`, `tea_geometry.gd`, `shaders/tea_*.gdshader` | Własny most drogowy i kładka, koryto i brzegi strumienia, rozmieszczenie ogrodu, ruch szyldu i nurtu oraz para GPU. Współrzędne są współdzielone przez teren, scenę i testy |
| `assets/textures/tea_ancient_bark_v1.png` | Nowa malarska kora, natywne 1254×1254 px. Wbudowany image_gen, wyłącznie opis tekstowy, zachowany bez edycji; dokładny prompt w `tea-bend/BARK_PROMPT.txt`, SHA-256 w manifeście przyrostu |
| `scripts/adventures.gd`, nowe shadery efektów i `woodland_magic.gd` | Własne reguły przedmiotów, dopalacza i sekretu, materiały brodu, świetliki, smuga, rozbryzgi i liście GPU |
| `tools/build_soundscape.py`, `assets/audio/`, `scripts/soundscape.gd` | Pięć oryginalnych pętli syntetycznych, bez nagrań i sampli osób trzecich. Parametry i SHA-256 w `assets/audio/MANIFEST.json`; dźwięk przestrzenny w sześciu ograniczonych źródłach |
| `assets/textures/` | Wcześniejsze albedo i gałązka liści, sześć tekstur pierwszej bajkowej wyspy oraz sześć obrazów nocnego dopracowania. Wygenerowane wbudowanym imagegen wyłącznie z opisów tekstowych; prompty i hashe obu zestawów są w `fairytale-assets/` |
| `assets/textures/meadow_painted_v3.png` | Nowa malarska łąka 1254×1254 RGB, wbudowany image_gen, tylko opis tekstowy, bez skalowania; dokładny prompt i SHA-256 w `enchanted-island/` |
| Czcionki interfejsu | Niezmienione Barlow Medium i Barlow Condensed Black Italic z Google Fonts; SIL OFL 1.1 w `assets/fonts/OFL.txt`. Czcionka awaryjna pochodzi z silnika; informacje prawne w spisie komponentów Godot |
| `scripts/menu_art.gd`, `assets/ui/*.svg` | Własna kompozycja menu, skośna krawędź, flaga, style kontrolek i proste ikony wektorowe utworzone w kodzie; bez generowanego obrazu menu ani zewnętrznego szablonu UI |
| `runtime/Godot.exe` | Niezmieniony oficjalny silnik, lokalna kopia pomijana przez Git |
| Testy, sceny i konfiguracja | Utworzone dla tego prototypu |

Kod przygotowano z pomocą asystenta AI na podstawie opisu funkcji i własnych decyzji implementacyjnych. Nie tłumaczono źródeł poprzedniej gry na GDScript i nie przenoszono do nowego projektu plików napisanych wcześniej wewnątrz jej forka. Nie użyto jego nowych tekstur ani shaderów GPU.

Nowy zestaw graficzny rozpoczęto 2026-11-15. Albedo powstały z tekstowych opisów cedru, płótna i nawierzchni, bez zrzutów poprzedniej gry. Drugi przyrost dodał wygenerowaną gałązkę seagrape na prawdziwie przezroczystym tle; alfa pozostała zachowana w PNG i jest używana przez shader wycinający liście. Wszystkie cztery PNG mają natywne 1254×1254 px; nie podnoszono rozdzielczości sztucznie i nie oznaczono tych plików jako 2K/4K. Normalne materiałów są wyliczane w shaderach GPU; maska kurzu jest niezależnym zasobem proceduralnym tworzonym przy przygotowaniu emitera. Pojazdy, architektura, pierzaste palmy i rig mają postać edytowalnych źródeł GDScript. Kolejny przyrost zastąpił wcześniejszego pilota postaciami Akademii Oli: zaimportowano jej Żabola, przygotowano adaptację Świnki i zachowano ilustracje oraz źródła geometryczne w dokumentacji. Żaden z tych zasobów nie pochodzi z poprzedniej gry.

Wcześniejszy fork był analizowany i modyfikowany w tej samej rozmowie, dlatego tego procesu nie należy przedstawiać jako formalnej implementacji clean room z izolowanymi zespołami. Ten zapis dokumentuje sposób utworzenia prototypu; nie zastępuje przeglądu praw do gotowego wydania.

Nowe repozytorium nie ma wspólnej historii Git z forkiem i nie zawiera jego podmodułów ani danych gry. Mechanika wyścigu, okrążenia, AI i podział ekranu są realizowane przez nowy kod. Nazwy, projekty torów, postaci i oprawa finalnej gry wymagają własnej produkcji zgodnej z pełną specyfikacją.

Oficjalne źródła zależności:

- [Pobieranie Godot](https://godotengine.org/download/windows/)
- [Licencja Godot](https://godotengine.org/license/)
- [Dokumentacja Godot](https://docs.godotengine.org/en/stable/)

Pełne informacje silnika i jego bibliotek odczytano z używanego pliku wykonywalnego przez `tools/write_engine_notices.gd` i zapisano w `GODOT_NOTICES.json`.
