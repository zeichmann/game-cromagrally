# Przebudowa podobieństwa postaci

Użytkownik odrzucił dotychczasowe modele 2026-11-16. Nie należy przedstawiać ich jako zaakceptowanych odpowiedników Akademii Oli.

Właściwe referencje to oryginalne portrety `public/swinka-game-premium-v2/avatar-{swinka,zabol}.webp` z lokalnej Akademii Oli. Kopie są zachowane jako `canonical-swinka.webp` i `canonical-zabol.webp`. Poprzednia adaptacja opierała się na wariantach z gry w szachy oraz zmodyfikowanym modelu Żabola; nie zachowała właściwych proporcji i stroju.

## Materiały przygotowane lokalnie

- [Świnka — obraz wejściowy](swinka-model-input.png): różowa kokarda, czarno-złoty kapelusz z emblematem, czerwona kurtka, kremowy żabot, krótki szeroki ryjek i brązowe oczy. Bez dodanych ludzkich włosów.
- [Żabol — obraz wejściowy](zabol-model-input.png): szeroka zielona głowa, oczy osadzone w naturalnych wyniosłościach, zintegrowany pysk i żuchwa, łagodny uśmiech, kapelusz z kotwicą i niebieski strój.
- [Żabol — arkusz poglądowy](zabol-study-v1.png): ilustracyjne studium głowy oraz sylwetki z kilku stron.

Obrazy wygenerowano wbudowanym imagegen, przekazując oryginalne portrety jako referencje tożsamości. Są materiałami do modelowania, **nie modelami 3D, teksturami produkcyjnymi ani zrzutami gry**. Arkusz Świnki z dodanymi włosami odrzucono. Rozmiary, kanał alfa i hashe: [ASSET_MANIFEST.json](ASSET_MANIFEST.json). Dokładne prompty: [PROMPTS.json](PROMPTS.json). Podobieństwo nadal podlega ocenie przy modelowaniu; samo wygenerowanie ilustracji nie zamyka zadania.

## Wymagania dla nowych modeli

Każda postać potrzebuje osobnej anatomii głowy. Świnka ma miękką, szeroką twarz, osadzone oczy, krótki owalny ryjek, trójkątne opadające uszy i różową kokardę; nie powinna powstać przez przemalowanie geometrii Żabola. Żabol ma szeroki, ciągły pysk, zaokrągloną żuchwę i oczy połączone z głową skórą oraz powiekami. Odrzucić wystające białe kule oczu, osobne kuliste policzki, płaską listwę zamiast pyska i przerażoną minę.

Przed osadzeniem w pojazdach porównać rzeczywiste rendery nowych siatek z portretami: przód, trzy czwarte, profil i zbliżenie twarzy. Dopiero potem przygotować pozę kierowcy, wagi, animacje oraz warianty wydajnościowe. Sprawne testy i animacje nie zastępują kontroli podobieństwa.

## Stan generacji 3D

Pinokio było nieosiągalne. Integracja fal nie jest połączona. Odczytano publiczne API oficjalnego [demo Microsoft TRELLIS.2](https://huggingface.co/spaces/microsoft/TRELLIS.2) i przygotowano lokalnego klienta. Wysyłka obrazu do tego serwisu została odrzucona przez automatyczny przegląd uprawnień: dotychczasowa zgoda na użycie postaci nie obejmuje przekazania prywatnego artworku temu dostawcy. Obrazów nie wysłano; wymagana jest osobna zgoda użytkownika na wysłanie dwóch wskazanych obrazów wejściowych. Pliki opuszczą wtedy komputer i zostaną przetworzone w publicznym demo na Hugging Face.

Aktualizacja 2026-11-17: aktywne są siatki `assets/characters/academy_v5/`, zbudowane lokalnie przez `tools/organic_character_builder.gd` i `tools/organic_face_geometry.gd` na własnej konstrukcji v4/v3. Oczy mają zagłębione tęczówki i osobną rogówkę, skóra trzy nowe materiały z tekstowych promptów, a mimika i spojrzenie nadal działają na GPU. Wewnętrzny brzeg białka podąża za tęczówką. Poprzednie wersje pozostają zachowane. Nie użyto zewnętrznego demo ani billboardów. [Opis modeli](../CHARACTERS.md), [porównanie z referencjami i natywne obrazy](../academy-v5/README.md). Podobieństwo pozostaje do oceny użytkownika; referencje z tego folderu nadal nie są zrzutami gry.
