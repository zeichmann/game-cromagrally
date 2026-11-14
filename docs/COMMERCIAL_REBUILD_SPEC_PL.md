# Specyfikacja niezależnej gry wyścigowej do wydania komercyjnego

Wersja: 0.1, 14 listopada 2026. Status: projekt do przeglądu przed implementacją.
Identyfikator roboczy: `IndependentRacer`. To identyfikator techniczny, nie sprawdzona nazwa handlowa.

## 1. Cel i definicja pełnego zakresu

Powstaje nowa gra zręcznościowa z walką pojazdów, kampanią i arenami. Celem jest równoważność funkcjonalna trybów i skali zawartości Cro-Mag Rally, z samodzielnie zaprojektowaną fizyką, oprawą, trasami, pojazdami, dźwiękiem i interfejsem. Nie jest wymagana identyczność prowadzenia, grafiki ani układów poziomów.

| Obszar | Pełne wydanie 1.0 |
| --- | --- |
| Tryby | 7: trening, kampania pucharowa, wyścig wieloosobowy, dwa warianty berka, eliminacja, drużynowe odzyskiwanie przedmiotów |
| Zawartość | 9 nowych tras, 8 nowych aren, 10 pojazdów lądowych, 1 pojazd podwodny |
| Zawodnicy | Do 6 pojazdów w wyścigu; miejsca uzupełniane przez AI |
| Gra lokalna | 1–4 osoby, maksymalnie cztery niezależne widoki |
| Sieć LAN | 2–6 osób, jeden gracz na klienta; prywatna sesja z gospodarzem |
| Postacie | 2 samodzielnie zaprojektowane postacie kierowców, warianty strojów i oznaczeń |
| Wyposażenie | 9 klas przedmiotów aktywowanych i 3 klas efektów natychmiastowych |
| Postęp | 3 puchary po 3 trasy, odblokowania, zapis kampanii i lokalne rekordy |
| Poziomy trudności | 4, z osobnymi profilami AI i warunkami awansu |
| Platformy | Windows x64 jako pierwsza; Linux x64 i macOS arm64 jako bramki pełnego 1.0 |
| Języki | Polski i angielski, cały interfejs lokalizowalny |
| Dystrybucja | Samodzielna płatna aplikacja, bez obowiązkowego konta i usług sieciowych |

Siedem trybów, liczby tras/pojazdów i rozdzielenie gry lokalnej/sieciowej ustalono na podstawie lokalnej instrukcji i publicznych deklaracji portu. Instrukcja historycznego oryginału opisuje rozgrywkę sieciową; obecny port oferuje do czterech graczy lokalnych i informuje o nieprzywróconej sieci. W tej specyfikacji LAN jest świadomie częścią pełnego zakresu, a nie funkcją już dostępną.

Wyłączone z 1.0: publiczny matchmaking, serwery dedykowane, konta/chmura, konsole, telefony, przeglądarka, warsztat modów, edytor poziomów dla użytkowników i mieszane sesje LAN z podzielonym ekranem na kliencie. Ich brak nie usuwa żadnego z siedmiu trybów.

## 2. Granica niezależności i warunki wydania

Przepisanie plików lub zmiana nazw nie stanowią same w sobie podstawy do komercjalizacji obecnej modyfikacji. Cro-Mag Rally i jego port zachowują własne prawa i licencję CC BY-NC-SA. Nowe wydanie wymaga odrębnej implementacji i pochodzenia wszystkich zasobów. Nie jest tu deklarowane uzyskanie zgody właścicieli oryginału ani przeprowadzenie formalnej procedury clean-room.

| Kategoria | Decyzja dla nowej gry |
| --- | --- |
| Źródła Pangea/jorio i biblioteka Pomme | Nie importować ani nie tłumaczyć linia po linii |
| Dodane w obecnym forku shadery i kod GPU | Zaimplementować ponownie na API nowego silnika; nie przenosić plików |
| Modele, animacje, mapy, kolizje, checkpointy | Nowe projekty i nowe dane; bez eksportu lub odrysowywania oryginalnych poziomów |
| Muzyka, efekty, głosy i teksty | Nowe nagrania/kompozycje/teksty lub materiały z potwierdzoną licencją komercyjną |
| Cztery obecne tekstury HD | Zestaw zastąpić w całości; trzy powstały z referencji oryginału, nie traktować ich jako niezależnego pakietu |
| Nowe obrazy AI | Generować z samodzielnych briefów, bez plików, screenshotów i rozpoznawalnych elementów oryginału; zapisywać pochodzenie i poddać kontroli podobieństwa |
| Nazwy, logo, bohaterowie, projekty pojazdów | Nowa tożsamość; nazwa handlowa przechodzi osobne sprawdzenie przed premierą |
| Biblioteki, fonty, dodatki, sample | Lista komponentów i warunki licencji dla każdej wersji; bez założenia, że materiał bezpłatny jest dozwolony komercyjnie |

Nowy projekt otrzyma osobne repozytorium i własne zasady licencjonowania. Obecne repozytorium pozostaje dokumentacją istniejącej modyfikacji; jego historii i LICENSE nie przenosi się jako fundamentu nowej gry. Rejestr dopuszczonych materiałów powstaje przed importem do nowego projektu. W specyfikacji nie rozstrzyga się praw autorskich do samych wyników AI ani wyłączności do nich.

Każdy zasób ma wpis: identyfikator, autor/dostawca, źródło, data, licencja i jej kopia, dowód zakupu/zgody albo plik źródłowy pracy własnej, zakres zmian, użycie AI i prompt, zależności oraz status dopuszczenia. Każdy import wymaga statusu `commercial_use_verified`; niewyjaśnione materiały są wyłączone z paczki wydania.

Bramka wydania: kompletne pochodzenie zasobów, wymagane noty bibliotek, zweryfikowana tożsamość handlowa, przegląd ryzyk podobieństwa i praw do materiałów. Taki proces ogranicza ryzyko, ale specyfikacja techniczna nie gwarantuje prawnej niezależności gotowej gry.

## 3. Własna tożsamość i kierunek artystyczny

Propozycja świata: kolorowy archipelag fantastycznych wysp, gdzie małe gildie budują pojazdy z wikliny, ceramiki, żywicy, drewna i tkanin. Kierowcy są nowymi postaciami o oryginalnych sylwetkach i osobowościach. Oś postępu stanowią trzy ligi wyspiarskie, bez odtwarzania epok, bohaterów, strojów ani narracji Cro-Mag Rally.

Kierunek: czytelne, stylizowane 3D z materiałami PBR i ręcznie projektowanym kolorem. Priorytetem są sylwetka pojazdu, czytelny tor, widoczność zagrożeń i rozróżnialność czterech widoków. Detal materiałów wspiera kompozycję; nie zastępuje jej szumem i nadmiernym połyskiem.

Wszystkie nazwy niżej są etykietami projektowymi. Zespół tworzy osobną biblię postaci, logo, palet, proporcji i UI; nie korzysta z oryginalnej gry jako wzorca do kopiowania grafiki.

## 4. Wspólny model rozgrywki

**Jazda:** przyspieszenie, hamowanie, cofanie, skręt analogowy, kontrolowany poślizg, wyskoki, zderzenia i przywrócenie na trasę. Początkowy model to własny kontroler pojazdu z próbkowaniem kontaktu z podłożem, oporem bocznym i stabilizacją; parametry dobierane w prototypie, nie kopiowane z oryginalnych tabel.

**Podłoża:** co najmniej grunt, kamień, mokra nawierzchnia, śliska nawierzchnia i podłoże spowalniające. Materiał steruje przyczepnością, oporem, dźwiękiem, śladami oraz efektami. Kolizje korzystają z uproszczonych, samodzielnych siatek.

**Pojazd podwodny:** oddzielny kontroler wyporu/oporu i kontaktu z trasą. Podstawowe akcje sterowania są takie same jak na lądzie; kamera i automatyczna stabilizacja nie wymagają dodatkowej osi wejścia. Pociski podwodne mają własny balans.

**Checkpointy:** zaliczenie przejazdu wymaga właściwej kolejności i kierunku. Pozycja w stawce wynika z okrążenia, checkpointu i odległości wzdłuż legalnej trasy. Skrót omijający bramki nie daje postępu. Powrót po wypadnięciu nie przeskakuje checkpointów i nie duplikuje znajdziek.

**Obrażenia i efekty:** obrażenia od pocisków, taranowania i zagrożeń środowiska, okresy ochronne po odrodzeniu, ograniczenie łańcuchowego ogłuszania. Liczby i czasy znajdują się w danych balansu. Obrażenia mają jedno źródło prawdy niezależne od liczby cząsteczek i klatek renderowania.

**Kamera:** widok pościgowy z ochroną przed zasłanianiem i co najmniej dwa ustawienia odległości. Odrębna kamera dla każdego gracza; brak uzależnienia fizyki od wybranego widoku. Potrząsanie i rozmycie ruchu można wyłączyć.

## 5. Siedem trybów — reguły kompletnego 1.0

| ID | Tryb projektowy | Uczestnicy i zwycięstwo | Wymagane zachowania |
| --- | --- | --- | --- |
| M01 | Trening | 1 gracz, do 5 AI; domyślnie 3 okrążenia | Wybór odblokowanej trasy, pojazdu i trudności; pomiar okrążeń/całego przejazdu, lokalne rekordy, restart |
| M02 | Liga wypraw | 1 gracz i 5 AI; 3 ligi po 3 wyścigi | Awans wymaga ukończenia wyścigu i zebrania 8 własnych znaczników. Na dwóch łatwiejszych poziomach akceptowane podium, na dwóch trudniejszych zwycięstwo. 3 ponowienia na ligę; zapis po ukończonym etapie, odblokowanie kolejnej ligi i pojazdów |
| M03 | Wyścig | 2–4 lokalnie lub 2–6 LAN, opcjonalne AI do 6 aut | Wspólny start, domyślnie 3 okrążenia, pełna klasyfikacja, limit oczekiwania na pozostałych po pierwszym finiszu, rewanż |
| M04 | Unikaj znacznika | Minimum 2 uczestników; ostatni pozostający wygrywa | Jedna oznaczona osoba. Jej własny licznik maleje; kontakt przekazuje oznaczenie. Przy wyczerpaniu czasu eliminacja. Mapę pozycji przeciwników ma wyłącznie oznaczony gracz |
| M05 | Utrzymaj znacznik | Minimum 2 uczestników; pierwszy z wymaganym łącznym czasem oznaczenia | Oznaczenie przejmowane przez kontakt. Czas sumuje się pomiędzy przejęciami. Docelowo 120 s, ustawialne 60/120/180 s. Oznaczony nie widzi pozycji przeciwników na mapie; pozostali je widzą |
| M06 | Ostatni na arenie | Minimum 2 uczestników; ostatni z dodatnim zdrowiem | Zdrowie zmniejszane taranowaniem, wyposażeniem i zagrożeniami. Brak odrodzeń w rundzie. Eliminowani oglądają ocalałych. Jednoczesna eliminacja wszystkich daje remis |
| M07 | Odzyskaj relikty | Dwie drużyny, 2–4 lokalnie lub 2–6 LAN | Po 6 przedmiotów każdej drużyny początkowo w bazie przeciwnika. Trzeba dowieźć własne do swojej bazy. Można przenosić i ukrywać przedmioty przeciwnika. Trafienie/taranowanie wymusza upuszczenie; dostawa naliczana tylko raz. Wygrywa drużyna z kompletem |

Reguły M04–M07 obsługują AI jako uczestników dopełniających, ale zawsze pozostaje co najmniej jeden człowiek w sesji. Dla M07 edytor meczu domyślnie wyrównuje drużyny; nierówny skład wymaga świadomego ustawienia. Tryby sieciowe i lokalne korzystają z tych samych reguł.

W M04/M05 przekazanie oznaczenia ma krótki, konfigurowalny okres blokady natychmiastowego oddania. Ustawienia bazowe M04: 120 s na gracza. M07: jedna niesiona rzecz, przycisk użycia upuszcza ją zamiast strzelać; odrodzenie po eliminacji po 5 s z 2 s ochrony. Wartości są propozycją balansu, nie pomiarem oryginału.

Znaczniki kampanii są przypisane do jednego przejazdu i nie są potrzebne w M01/M03. Stan ich zebrania nie może zostać przeniesiony przez restart. Po utracie wszystkich ponowień liga zaczyna się od pierwszego wyścigu, bez odebrania wcześniej trwale odblokowanych treści.

## 6. Pojazdy, kierowcy i AI

| Rodzina | Liczba | Rola |
| --- | --- | --- |
| Lekkie | 3 | Przyspieszenie, zwrotność lub kontrolowany drift; słabsza odporność na taranowanie |
| Uniwersalne | 4 | Różne kompromisy prędkości, przyczepności i amortyzacji |
| Ciężkie | 3 | Stabilność i masa, kosztem startu lub ciasnych nawrotów |
| Podwodna | 1 | Pojazd przeznaczony do nowej trasy wodnej, odrębny model ruchu |

Każdy pojazd ma nowy model, własne proporcje, sylwetkę, animowane części, dźwięk i czytelną kartę właściwości. Cztery podstawowe charakterystyki menu: prędkość, przyspieszenie, prowadzenie i amortyzacja. Masa i odporność są częścią balansu. Nie ma jednego pojazdu dominującego we wszystkich czterech statystykach.

Dwie postacie mają komplet animacji: jazda, skręt/wychylenie, trafienie, użycie wyposażenia, zwycięstwo i porażka. Proporcje, rig i gesty powstają samodzielnie. Barwy strojów i symbole odróżniają graczy; identyfikacja drużyn nie opiera się wyłącznie na kolorze.

AI: linia jazdy i wyprzedzanie, hamowanie przed zakrętem, omijanie przeszkód, odzyskiwanie po kolizji, powrót z zakleszczenia, dobór i celowanie wyposażeniem. Areny wymagają odrębnych strategii pogoni, ucieczki, walki i transportu reliktów. Trudność zmienia celność, czas reakcji i planowanie; ukryty teleport lub obchodzenie checkpointów są niedopuszczalne. Pomoc słabszym AI, jeśli wystąpi, ma limity i opcję wyłączenia.

## 7. Wyposażenie i efekty

Wspólne zasady: jeden typ przedmiotu w ekwipunku, licznik ładunków, użycie do przodu lub do tyłu, odrębne efekty automatyczne z licznikami czasu. Kolejność nakładania, odnawianie i limity kumulacji są jawne w danych. Trafienie ma czytelny sygnał wizualny i dźwiękowy.

| ID | Funkcja wymagająca implementacji | Niezależny kierunek wizualny |
| --- | --- | --- |
| W01 | Pocisk obszarowy rzucany łukiem | Ceramiczna kapsuła energii |
| W02 | Pułapka obniżająca przyczepność | Rozlana żywica |
| W03 | Ograniczony czasowo dopalacz | Rozwijana dysza wiatrowa |
| W04 | Pocisk samonaprowadzający | Świetlna kapsuła ze skrzydełkami, bez ptasiego bohatera |
| W05 | Szybki pocisk lecący w zadanym kierunku | Wyrzutnik sprężonego powietrza |
| W06 | Atak wznoszący się i opadający na cel | Ładunek chmurowy |
| W07 | Pocisk do walki pod wodą | Wirujący ładunek wodny |
| W08 | Obszarowe, krótkie unieruchomienie/spowolnienie | Pole krystaliczne o nowej oprawie |
| W09 | Uzbrajana z opóźnieniem mina | Składana kotwica energii |
| B01 | Czasowa poprawa przyczepności | Oświetlenie obręczy i ikona mechanizmu |
| B02 | Czasowe zwiększenie stabilności/amortyzacji | Zmiana pracy zawieszenia i odrębna ikona |
| B03 | Czasowe ukrycie przed przeciwnikami i ich mapami | Shader maskujący; własny pojazd nadal rozpoznawalny dla kierowcy |

Każda klasa ma oddzielne dane dla pojazdów lądowych i podwodnych, jeśli jest używana w obu środowiskach. Niedostępny w danym środowisku przedmiot nie pojawia się w puli losowania. Krótkie ogłuszenia nie mogą w nieskończoność blokować sterowania. Obszar obrażeń nie jest wyznaczany losowymi cząsteczkami GPU.

## 8. Zawartość poziomów

Poniższa lista określa funkcję projektową, nie układ dawnej trasy. Każda trasa dostaje nowy szkic przebiegu, wysokości, sektory, punkty orientacyjne i rozstawienie znajdziek. Zatwierdzenie układu następuje na szarych bryłach przed produkcją grafiki.

| ID | Liga/rola | Propozycja własnego otoczenia |
| --- | --- | --- |
| R01 | Wprowadzenie, łagodne zakręty | Wyspa wiatraków i szerokie groble |
| R02 | Przyczepność i skróty | Mokradła porośnięte trzciną i ceramiczne mostki |
| R03 | Pionowe różnice wysokości | Ogrody na tarasach klifu |
| R04 | Drift i śliskie odcinki | Szkliste solne równiny |
| R05 | Skoki i wybór linii | Warsztaty zawieszone nad kanionem |
| R06 | Obszary zagrożeń | Wyspa parowych gejzerów |
| R07 | Precyzyjna jazda | Kamieniołom o spiralnych tarasach |
| R08 | Duża prędkość i zmiana pogody | Wybrzeże burzowych latarni |
| R09 | Sterowanie podwodne | Świecące rafy i zatopione naturalne jaskinie |

Początkowy cel długości: 2–4 min na okrążenie dla przeciętnego gracza; korygowany po prototypie. Każda trasa ma trasę AI, legalne checkpointy, bezpieczne miejsca powrotu, 8 punktów znaczników kampanii, punkty wyposażenia, kolizje, strefy audio i prezentację wyboru.

Osiem aren A01–A08: otwarty plac, teren z osłonami, wielopoziomowa kopalnia, symetryczne dwie bazy, połączone pierścienie, sieć dziedzińców, wyspy z kładkami i amfiteatr naturalnych skał. Wszystkie obsługują M04–M07; dla M07 otrzymują dwie zweryfikowane bazy i komplet punktów przedmiotów. Każda arena musi mieć co najmniej dwie drogi pomiędzy głównymi strefami i brak nieosiągalnych miejsc odkładania reliktu.

## 9. Interfejs, sterowanie i zapis

Przepływ: ekran główny → wybór trybu → konfiguracja sesji → dołączenie graczy → wybór postaci/pojazdów → poziom → rozgrywka → wyniki → rewanż/następny etap/menu. Każdy ekran działa klawiaturą i kontrolerem; brak wymaganych kliknięć myszą.

Konfiguracja obejmuje liczbę graczy, drużyny, AI, trudność, trasę/arenę oraz parametry trybu. Wybór pojazdu wskazuje blokady i zgodność ze środowiskiem. Wyniki wyświetlają pozycję/czas lub wynik trybu, bez automatycznego przerywania meczu pozostałym graczom.

HUD per gracz: czas lub zdrowie właściwe dla trybu, okrążenie/pozycja, ekwipunek i ładunki, liczniki efektów, komunikaty trafień, wskazanie kierunku po wypadnięciu, mapa według reguł. W M07 dodatkowo drużyna, niesiony przedmiot i wynik obu drużyn. Minimapę i elementy przeciwników filtruje logika meczu, a nie wyłącznie niewidoczny materiał.

Sterowanie: klawiatura dla jednego stanowiska oraz do czterech niezależnie przypisanych padów. Każda akcja remapowalna: jazda, skręt, hamulec, przedmiot przód/tył, kamera, przywrócenie i pauza. Menu przypisania zapobiega sterowaniu dwoma graczami jednym padem. Odłączenie kontrolera lokalnie zatrzymuje sesję i daje możliwość ponownego przypisania. W LAN zatrzymuje tylko wejście danego gracza, bez pauzy całego serwera.

Podział ekranu: dla dwóch osób pionowy/poziomy, dla trzech i czterech układ 2×2; wolny czwarty panel przy trzech osobach pokazuje neutralne informacje o meczu. HUD zachowuje marginesy i czytelność przy 1080p. Dostępne są skala UI, ograniczenie błysków, wyłączenie drgań kamery, niezależne poziomy muzyki/efektów i oznaczenia drużyn symbolami.

Zapis ma wersjonowany schemat, atomową podmianę pliku i kopię ostatniego poprawnego stanu. Obejmuje odblokowania, etap kampanii/ponowienia, rekordy, ustawienia i mapowanie. Uszkodzony plik nie blokuje startu. Migrowanie zapisu z nowej gry do starszej wersji nie jest wymagane; aktualizacja w przód wymaga testu migracji.

## 10. Silnik i architektura

Rekomendacja: Godot 4, wersja stabilna przypięta wraz z szablonami eksportu na początku implementacji. Licencja MIT pozwala na komercyjną dystrybucję i własne warunki licencji gry; należy zachować wymagane noty silnika i komponentów. Nie przejmuje się przez to automatycznie praw do importowanych zasobów. Źródło: [Godot — License](https://godotengine.org/license/).

Bazowy renderer Forward+ dla desktopu; osobno testowany profil oszczędny i tryb Compatibility. Godot rozdziela te renderery i ich możliwości; profil zapasowy nie może obiecywać tego samego efektu wizualnego. Źródło: [Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).

| Moduł | Odpowiedzialność i granica |
| --- | --- |
| Session/ModeRules | Stan meczu i reguły M01–M07; wspólny kod dla gry lokalnej i LAN |
| VehicleController | Własny integrator zręcznościowy na fizyce silnika, ląd/woda |
| Course/CheckpointGraph | Walidacja postępu, ranking, bezpieczny powrót i dane AI |
| Equipment/StatusEffects | Przedmioty, obrażenia, nakładanie efektów, pula obiektów |
| AI | Planowanie jazdy i cele aren, z ograniczonym budżetem czasu |
| Presentation | Kamera, HUD, animacje i efekty; nie ustala wyniku meczu |
| Input/LocalPlayers | Urządzenia, remapowanie, podział ekranów |
| Persistence | Wersjonowany zapis i migracje |
| LAN | Autorytatywny gospodarz, komendy wejścia, replikacja stanów i zdarzeń |
| Content/Provenance | Definicje pojazdów, torów, wyposażenia oraz dopuszczenie zasobów |

Reguły i narzędzia w GDScript; GDExtension/C++ tylko po wskazaniu kosztu przez profiler. Stały krok fizyki 60 Hz; rendering interpolowany. Built-in VehicleBody3D nie jest przyjmowany jako gotowa docelowa fizyka: dokumentacja wskazuje jego ograniczenia. Źródło: [VehicleBody3D](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html).

Proponowane dane: `VehicleSpec`, `EquipmentSpec`, `ModeConfig`, `CourseSpec`, `ArenaSpec`, `CampaignState`, `AssetProvenance`. Definicje z trwałymi ID, walidacją i bez zależności od nazw plików w interfejsie. Budowanie gry nie wymaga zainstalowanego Cro-Mag Rally ani dostępu do obecnego forka.

## 11. GPU i jakość obrazu

Deformacja siatek szkieletowych odbywa się przez GPU; czas animacji, zdarzenia i dane potrzebne do gry są oceniane przez CPU. Dekoracyjne cząsteczki symuluje GPUParticles3D, z własnymi materiałami i limitami. Źródło możliwości systemu: [GPUParticles3D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html).

Pociski i strefy ognia mają niewielkie autorytatywne obiekty kolizyjne CPU; wizualny dym, iskry, śnieg i drobiny nie są odczytywane z GPU co klatkę. Dzięki temu liczba cząsteczek i jakość grafiki nie zmieniają obrażeń. Profile słabszego sprzętu mogą ograniczyć cząsteczki lub użyć uproszczonych efektów CPU, zachowując reguły meczu.

Wymagania zasobów: oryginalne modele z LOD, uproszczone kolizje, tekstury bazowe 2K dla pojazdów/ważnych rekwizytów, do 4K dla wyróżnionych materiałów środowiska. Albedo bez przypadkowego oświetlenia, osobno normal/roughness tam, gdzie istotne. Mipmapy, anizotropia, kontrola spójności gęstości texeli i kompresja właściwa dla platformy. Wielkość pliku nie jest kryterium jakości.

Nowa produkcja artystyczna wymaga wzorcowej sceny oświetlenia, oceny materiałów w ruchu, oględzin szwów kafelkowania i krawędzi alfa oraz testu czterech widoków. Żaden asset nie jest akceptowany wyłącznie na podstawie miniatury z generatora.

Cele wydajności są wymaganiami projektowymi, nie wynikami benchmarków:

| Profil | Cel do sprawdzenia w M2 |
| --- | --- |
| Zintegrowana grafika klasy Iris Xe, profil oszczędny | 1080p, 60 FPS dla jednego gracza; 30 FPS przy czterech widokach z obniżoną rozdzielczością renderowania |
| Karta klasy RTX 3060/RX 6600, profil wysoki | 1440p/60 FPS dla jednego gracza; 1080p/60 FPS przy czterech widokach |

Dokładne minimalne wymagania sprzętowe powstają po pomiarach. Pomiary obejmują średni czas klatki, 1% najwolniejszych klatek, CPU/GPU, pamięć i zmianę jakości. Ładowanie shaderów/materialów nie może regularnie przerywać wyścigu. Rozdzielczość dynamiczna, LOD i ograniczenie efektów per widok są elementami architektury, a nie dodatkiem na końcu.

## 12. LAN

Host ustala checkpointy, wynik, obrażenia, ekwipunek i relikty. Klient wysyła wejście, nie dowolną pozycję/wynik. Proponowany punkt startowy: symulacja 60 Hz, migawki 20 Hz, interpolacja innych pojazdów i lokalna predykcja z korektą; wartości do oceny na prototypie. Nie zakłada się deterministyczności fizyki Godota między platformami.

Lobby: utworzenie pokoju, dołączenie po adresie IP, lista graczy, gotowość, wybór trybu/poziomu, blokada startu przy niezgodnej wersji zawartości. Serwer ma limity liczby komunikatów i waliduje identyfikatory. Brak host migration w 1.0: utrata gospodarza kończy sesję komunikatem, bez uszkodzenia lokalnego zapisu. Rozłączenie klienta daje AI przejmujące pojazd lub bezpiecznie usuwa gracza zgodnie z regułą trybu.

M07 wymaga jednoznacznego właściciela każdego przedmiotu i idempotentnego naliczania dostawy. M04/M05 wymagają jednego autorytatywnego znacznika. Scenariusze LAN obejmują 0/50/100 ms opóźnienia, do 2% utraty pakietów i nieoczekiwane wyjście gracza. Docelowe tolerancje korekt ustala M5.

## 13. Produkcja zasobów i narzędzia

Minimalny inwentarz wydania: 17 poziomów, 11 kompletnych pojazdów z LOD i kolizjami, 2 rigi kierowców z animacjami, 12 rodzin wyposażenia/buffów, zestawy środowiskowe dla trzech lig, menu/HUD/ikony oraz oryginalne efekty i muzyka. Pierwszy plan dźwięku: 9 motywów tras, 4 współdzielone motywy aren i 2 motywy menu/wyników; ostateczny zakres ustala biblia audio.

Narzędzia wewnętrzne: walidator poziomu, podgląd checkpointów i AI, edycja punktów powrotu/wyposażenia, generator miniaturek, inspektor licencji, lokalizacja i walidator danych balansu. Źródła grafiki/animacji/audio przechowywane z eksportami; brak konieczności odtwarzania assetu z samego pliku końcowego.

Wyjściowe briefy AI opisują własny świat, materiały i funkcję, nie proszą o remaster oryginalnych postaci lub poziomów. Zasoby z AI przechodzą ręczny przegląd projektu i warunków użytego narzędzia. Nie przypisuje się im automatycznie wyłącznej ochrony prawnoautorskiej.

## 14. Etapy i bramki odbioru

| Etap | Dostarczany wynik | Warunek przejścia |
| --- | --- | --- |
| M0 — specyfikacja i pochodzenie | Ten dokument, biblia robocza, zasady importu, decyzja o osobnym repo | Przejrzany zakres i zasady pochodzenia; brak rozpoczęcia produkcji na danych oryginału |
| M1 — prototyp jazdy | 1 własna trasa z brył, 2 własne pojazdy, AI, checkpointy, 4 widoki | Stabilny przejazd 3 okrążeń, prawidłowe rankingi/powroty, niezależne sterowanie czterech osób |
| M2 — reprezentatywny wycinek | 1 finalna trasa, 1 arena, 2 finalne pojazdy, kierowca, GPU FX, HUD, trzy różne tryby | Przejście pomiarów CPU/GPU i kompletnej ścieżki licencyjnej każdego zasobu; zatwierdzenie oprawy |
| M3 — komplet reguł | Wszystkie M01–M07, wyposażenie, kampania, zapis i AI aren | Testy reguł i zapisu, bez atrap zwycięstwa, map lub odblokowań |
| M4 — komplet zawartości | 9 tras, 8 aren, 11 pojazdów, 2 kierowców i komplet oprawy | Walidacja poziomów, rozgrywalność każdej kombinacji tryb/poziom oraz przegląd artystyczny |
| M5 — LAN i platformy | Pełne sesje 2–6 osób, eksporty Windows/Linux/macOS | Testy sieci i wejścia, zgodność zapisów i konfiguracji, obsługa błędów połączeń |
| M6 — kandydat wydania | Paczki instalacyjne/przenośne, licencje, credits, ustawienia, instrukcja | Wszystkie kryteria sekcji 15 i przegląd pochodzenia/marki przed sprzedażą |

M1/M2 nie są pełną grą i nie zamykają pełnego zakresu. Harmonogram i koszty produkcji ustala się po M2, na podstawie rzeczywistego tempa przygotowania zatwierdzonych zasobów i pomiarów split-screen. Zmniejszenie liczby tras, trybów lub pojazdów wymaga jawnej zmiany specyfikacji.

## 15. Kryteria akceptacji pełnego wydania

| ID | Test odbiorowy |
| --- | --- |
| F01 | Każdy z M01–M07 daje się uruchomić, rozegrać i prawidłowo zakończyć; wyniki/rewanż/menu działają |
| F02 | Wszystkie 9 tras zaliczają checkpointy, pomiar czasu i przywracanie pojazdu; osiem aren obsługuje oba berki, eliminację i relikty |
| F03 | Kampania obsługuje 3 ligi, 8 znaczników na trasę, ponowienia, warunki awansu, odblokowania i wznowienie po zamknięciu aplikacji |
| F04 | Oba berki mają prawidłowe liczniki, pojedynczego właściciela znacznika, blokadę natychmiastowego odbicia i wymagane filtrowanie map |
| F05 | Eliminacja usuwa gracza z aktywnej rundy; obsługuje ostatniego ocalałego i remis |
| F06 | Relikt ma dokładnie jedną lokalizację/właściciela; podniesienie, upuszczenie, ukrycie, dostarczenie i przerwanie po trafieniu nie duplikują punktów |
| F07 | Każdy z 11 pojazdów jest grywalny w swoim środowisku, ma animację, kolizję i własny profil prowadzenia |
| F08 | Wszystkie 9 przedmiotów i 3 buffy działają z AI, lokalnie i w LAN; nie zmieniają wyniku w zależności od jakości efektów |
| F09 | AI kończy wyścig i rozgrywa cele aren; brak trwałych zakleszczeń i ukrytego omijania bramek |
| I01 | Cztery urządzenia wejścia nie sterują cudzym slotem; odłączenie/ponowne przypisanie nie niszczy sesji |
| I02 | Wszystkie menu i ekrany wyników działają bez myszy, w polskim i angielskim |
| I03 | HUD czterech osób pozostaje czytelny przy docelowej rozdzielczości; drużyny rozróżnialne bez samego koloru |
| S01 | Zapis przetrwa przerwanie zapisu, błędny plik i aktualizację zgodną ze schematem; brak utraty zatwierdzonych odblokowań |
| N01 | Sześć stanowisk LAN rozgrywa każdy tryb bez rozjechania wyniku, przedmiotów i timerów |
| N02 | Wyjście klienta/hosta i niezgodna wersja mają przewidywalne zachowanie; nie uszkadzają lokalnego profilu |
| G01 | Profiler potwierdza skinning/FX na GPU w profilu docelowym; brak ciągłego odczytu pełnych buforów cząsteczek do CPU |
| G02 | Profil zapasowy zachowuje mechanikę mimo uproszczeń wizualnych; cele wydajności zweryfikowane po M2 i ponownie przed premierą |
| G03 | Mipmapy, alfa, LOD, shadery i materiały sprawdzone w ruchu oraz na czterech widokach |
| Q01 | Co najmniej godzina wyścigów/rewanżów i 50 zmian scen bez awarii, narastającego zużycia pamięci i zgubionych kontrolerów |
| Q02 | Świeży komputer uruchamia eksport bez SDK, edytora i plików poprzedniej gry; paczka ma zweryfikowaną integralność |
| L01 | Każdy plik wydania ma ustalone pochodzenie; nie ma danych ani kodu importowanych z Cro-Mag Rally/Pomme/obecnego forka |
| L02 | Dołączono noty zależności, dokumentację zasobów i sprawdzono nazwę/branding oraz ryzyka podobieństwa przed sprzedażą |

## 16. Decyzje robocze i otwarte kwestie

Przyjęte do planowania: Godot 4, nowa tożsamość wyspiarska, siedem trybów, pełna liczba tras/pojazdów, cztery osoby lokalnie i sześć w LAN, start od Windows. Są to decyzje projektowe do przeglądu, nie istniejące funkcje nowej gry.

Przed M1 należy zatwierdzić nazwę roboczą i kierunek wizualny. Przed M2: docelowy sprzęt, odczucie prowadzenia, zasady dostępu do treści w grach lokalnych/LAN oraz wygląd profilu oszczędnego. Przed M4: pełne listy zasobów, budżet audio/lokalizacji i przyjęte licencje. Przed M6: marka, prawa do materiałów, docelowe kanały sprzedaży i ich wymagania.

Publikacja komercyjna nowej gry staje się celem dopiero po jej wykonaniu i przejściu tych bramek. Obecna paczka Cro-Mag Rally GPU HD zachowuje dotychczasową licencję i nie otrzymuje z tego dokumentu nowych uprawnień.

## 17. Podstawa ustalenia zakresu

Lokalne materiały użyte do analizy funkcji: `Source/Headers/main.h`, `Source/Headers/player.h`, `docs/Manual/english/` (rozdziały trybów i wyposażenia), `README.md`. Nie są materiałem do skopiowania do nowej implementacji. Publiczny opis portu: [jorio/CroMagRally](https://github.com/jorio/CroMagRally).

Pozostałe źródła decyzji technicznych: oficjalne dokumenty Godota wskazane w sekcjach 10–11. Wersję silnika i licencje konkretnych zależności należy ponownie zweryfikować przy zakładaniu projektu i przypięciu wersji.
