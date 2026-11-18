# Kierunek nocnego dopracowania

Punkt wyjścia: `f97bc81`, 16 listopada 2026. Użytkownik zlecił dalszą samodzielną pracę nad bardzo dopracowaną, bajkową trasą i jej okolicą.

Cel wizualny: jasny, przytulny świat ilustracyjnego 3D. Kamień w odcieniach kości słoniowej, matowe dachówki błękitne i liliowe, spokojne szałwiowe zielenie, kremowe i różowe kwiaty, miękkie ciepłe światło. Naturalne zagęszczenia i przerwy, czytelne miejsca oraz detale widoczne z kamery jazdy.

Najważniejsze poprawki:

- Zastąpić wygląd gładkich kul koronami z wyraźnymi warstwami liści; odróżnić stokrotki, lawendę i róże także kształtem.
- Dopracować elewacje, dachy, wejścia i małe ogródki; nadać wariantom domków różne formy.
- Przebudować wodospad w wiarygodną kaskadę ze źródłem, skalnymi progami, pianą i mgiełką.
- Dodać szczegóły kamienia, łąki, brzegów i miejsc odpoczynku; unikać równych pasów identycznych dekoracji.
- Uzupełnić sylwetkę zamku i wykończenie portu, zachowując sześć charakterystycznych odcinków.
- Zmierzyć cienie i liczbę materiałów, następnie zmniejszyć koszt renderowania bez odbierania High bliskich detali.

Kontrola: rzeczywiste widoki silnika na całym okrążeniu, poprawne osadzenie obiektów, brak przenikania i otwartych siatek, działające profile jakości, testy reguł i sesji, pełny wyścig AI oraz oddzielne pomiary ruchomej gry. Diagnostyka nieruchomego widoku służy porównaniom A/B i nie zastępuje pomiaru wyścigu.

Granice: ten etap dotyczy otoczenia i jego renderowania. Tożsamość odrzuconych modeli kierowców nadal wymaga osobnej przebudowy. Żadne ilustracje Akademii Oli nie są wysyłane do zewnętrznego modelowania.

## Punkt kontrolny — 03:40 czasu polskiego

Przebudowano 33 aktywne modele, w tym trzy różne domki, pięć sylwetek drzew, prawdziwe róże i lawendę, wieżę zegarową, bramę i balkon zamku, trzy warianty łodzi, mostek, bluszcz i lilie wodne. Kaskada ma wspólną definicję ze źródłem i rzeźbą terenu. Nagie panele skalne zastąpiono nowym naturalnym wapieniem; gęstość terenu zwiększono do siatki 192×168.

Dodano pięć natywnych obrazów z opisów tekstowych we wbudowanym image_gen. Prompty oraz rozmiary i hashe są w `NIGHT_PROMPTS.json` i `NIGHT_ASSET_MANIFEST.json`. Naprawiono wyłączone mipmapy sześciu wcześniejszych tekstur. Nowe połączenie powierzchni ogranicza liczbę materiałów; kopie siatek kierowców zachowują wszystkie pozycje i wpływy kości, nadal bez akceptacji wyglądu.

Wykonano przegląd sześciu odcinków oraz sześciu ujęć krajobrazowych. Usunięto rośliny ze ścieżek i obrysów budynków, czarne szyby latarni oraz liniowy artefakt na szwie nieba. Kontrole: reguły 133 PASS, sesja 40 PASS, grafika PASS, otoczenie 161 PASS. To zapis pośredni; końcowe pomiary ruchomej gry i dokumentacja nastąpią po dalszym dopracowaniu.

## Końcowy stan nocnego etapu

Komplet urósł do 40 modeli, w tym płotków, kamiennych rabat, skrzynek pocztowych, pergoli różanej, wyposażenia portu i balonów. Rynek ma wyrównany teren i spójny bruk, domki różne bryły i szczegóły elewacji, paprocie oddzielne listki, a korony przestrzenne liście. Dodano szósty obraz — drobny piasek — i usunięto widoczną wcześniej kratkę na brzegu. Prześwit przy górnym progu wodospadu uwzględnia ruch powierzchni wody. Fontanny mają dekoracyjne emitery GPU.

Rozdzielczość widoków odpowiada fizycznemu oknu; High otrzymał MSAA 4×. Zmniejszono liczbę materiałów, wprowadzono drobniejsze grupy instancji i przesłony terenu. Kompilacja wariantów renderowania odbywa się za początkowym ekranem przygotowania, a nie podczas pierwszego przejazdu. Końcowe pomiary rozróżniają krótką jazdę, pełne okrążenie i cztery widoki.

Natywny przegląd obejmuje sześć odcinków, osiem krajobrazów, trzy warianty domków i osiem ujęć objazdu. Reguły 133 PASS, sesja 40 PASS, grafika PASS, otoczenie 195 PASS, audyt sześciu obrazów PASS. Zapisano rzeczywiste PNG i surowe JSON wraz z wynikiem zimnego startu, który ujawnił przycięcie przed dodaniem przygotowania shaderów. Szczegóły i ograniczenia sprzętowe: [GRAPHICS_VALIDATION.md](GRAPHICS_VALIDATION.md).

Run-tour.cmd pokazuje ukończone otoczenie w zapętlonym objazdzie. Esc przywraca menu i obsługę wejścia. Odrzucone podobieństwo kierowców pozostaje osobnym zadaniem.
