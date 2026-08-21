# Propositions d'icône

Cinq pistes générées par `tool/generate_icon_concepts.py`, dans la palette du thème (asphalte, chalk, orange, teal), sans logo ni marque existante. Pour chaque piste : `N_nom.png` (1024×1024), `N_nom_48.png` et `N_nom_48_grayscale.png` (test de lisibilité en petit et en monochrome), `N_nom_on_light.png` (rendu sur fond clair). Vue d'ensemble : `icon_concepts_contact_sheet.png`.

1. **`1_front_hoop`** — panier vu de face (panneau + arceau + filet). À 48 px l'arceau orange se fond dans le panneau blanc : l'identité "panier" disparaît.
2. **`2_stylized_net`** — filet stylisé en losanges. Silhouette forte en grand, mais le détail du tressage devient une bouillie à 48 px.
3. **`3_pin_ball`** — marqueur de carte fusionné avec un ballon (coutures à l'intérieur de la tête du marqueur). **Retenu** : seule piste qui reste lisible à 48 px et en niveaux de gris, et la seule qui montre à la fois ce que fait l'app (localiser) et son sujet (le basket).
4. **`4_abstract_geometric`** — ballon rebondissant au coin d'une tuile, accent teal. Propre mais n'évoque ni le basket ni la localisation sans le contexte des couleurs.
5. **`5_top_down_hoop`** — arceau vu de dessus, filet en corde tressée au centre. Très fort en grand ; en niveaux de gris à 48 px le tressage disparaît et il ne reste qu'un anneau générique.

Pour changer d'icône : reprendre le corps de `concept_pin_ball()` (ou une autre fonction) de `tool/generate_icon_concepts.py` dans `tool/generate_brand_assets.py`, relancer ce dernier, puis `dart run flutter_launcher_icons` et `dart run flutter_native_splash:create`.
