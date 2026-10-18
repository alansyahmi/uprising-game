import os
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import qn, nsdecls

def create_document():
    doc = docx.Document()

    # Define Color Palette
    # Primary: Deep Burgundy / Royal Blood (#6A1B29)
    # Secondary: Dark Slate Iron (#2C3E50)
    # Accent Gold: Antique Ochre (#B3822A)
    # Body Charcoal: (#2A2A2A)
    # Muted Gray: (#555555)
    # Shading Light: (#F8F6F2)
    # Shading Table Header: (#4A121A)
    
    # Page setup - Margins (1 inch)
    for section in doc.sections:
        section.top_margin = Inches(1)
        section.bottom_margin = Inches(1)
        section.left_margin = Inches(1)
        section.right_margin = Inches(1)
        
        # Configure Header & Footer
        footer = section.footer
        p_ft = footer.paragraphs[0]
        p_ft.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        p_ft.text = "UPRISING: THE BLOOD SACRAMENT — NARRATIVE & DESIGN BIBLE"
        p_ft.style.font.name = 'Georgia'
        p_ft.style.font.size = Pt(8.5)
        p_ft.style.font.color.rgb = RGBColor(140, 140, 140)

    # Base styles
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Georgia'
    normal_style.font.size = Pt(11)
    normal_style.font.color.rgb = RGBColor(40, 40, 40)
    normal_style.paragraph_format.line_spacing = 1.18
    normal_style.paragraph_format.space_after = Pt(6)

    # Helper XML functions
    def set_cell_background(cell, hex_color):
        tcPr = cell._tc.get_or_add_tcPr()
        shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
        tcPr.append(shd)

    def set_cell_margins(cell, top=140, bottom=140, left=180, right=180):
        tcPr = cell._tc.get_or_add_tcPr()
        tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
        tcPr.append(tcMar)

    def set_callout_border(cell, hex_color="6A1B29"):
        tcPr = cell._tc.get_or_add_tcPr()
        borders = parse_xml(
            f'<w:tcBorders {nsdecls("w")}>'
            f'<w:top w:val="none"/>'
            f'<w:left w:val="single" w:sz="36" w:space="0" w:color="{hex_color}"/>'
            f'<w:bottom w:val="none"/>'
            f'<w:right w:val="none"/>'
            f'</w:tcBorders>'
        )
        tcPr.append(borders)

    def set_table_borders(table, border_color="D0C8B8"):
        tblPr = table._tbl.tblPr
        borders = parse_xml(
            f'<w:tblBorders {nsdecls("w")}>'
            f'<w:top w:val="single" w:sz="6" w:space="0" w:color="{border_color}"/>'
            f'<w:left w:val="none"/>'
            f'<w:bottom w:val="single" w:sz="6" w:space="0" w:color="{border_color}"/>'
            f'<w:right w:val="none"/>'
            f'<w:insideH w:val="single" w:sz="4" w:space="0" w:color="{border_color}"/>'
            f'<w:insideV w:val="none"/>'
            f'</w:tblBorders>'
        )
        tblPr.append(borders)

    # Helper text formatting
    def add_title(text):
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(36)
        p.paragraph_format.space_after = Pt(4)
        run = p.add_run(text)
        run.font.name = 'Georgia'
        run.font.size = Pt(28)
        run.font.bold = True
        run.font.color.rgb = RGBColor(106, 27, 41) # #6A1B29
        return p

    def add_subtitle(text):
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(24)
        run = p.add_run(text)
        run.font.name = 'Georgia'
        run.font.size = Pt(13)
        run.font.italic = True
        run.font.color.rgb = RGBColor(140, 100, 35) # Antique Gold
        return p

    def add_h1(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(22)
        p.paragraph_format.space_after = Pt(8)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.font.name = 'Georgia'
        run.font.size = Pt(18)
        run.font.bold = True
        run.font.color.rgb = RGBColor(106, 27, 41)
        return p

    def add_h2(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(14)
        p.paragraph_format.space_after = Pt(5)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.font.name = 'Georgia'
        run.font.size = Pt(14)
        run.font.bold = True
        run.font.color.rgb = RGBColor(44, 62, 80)
        return p

    def add_h3(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(10)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.font.name = 'Georgia'
        run.font.size = Pt(12)
        run.font.bold = True
        run.font.italic = True
        run.font.color.rgb = RGBColor(140, 100, 35)
        return p

    def add_p(text, bold_prefix=""):
        p = doc.add_paragraph()
        if bold_prefix:
            r_b = p.add_run(bold_prefix)
            r_b.font.bold = True
            r_b.font.color.rgb = RGBColor(30, 30, 30)
        r_t = p.add_run(text)
        return p

    def add_bullet(text, bold_prefix=""):
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.space_after = Pt(4)
        if bold_prefix:
            r_b = p.add_run(bold_prefix)
            r_b.font.bold = True
            r_b.font.color.rgb = RGBColor(30, 30, 30)
        r_t = p.add_run(text)
        return p

    def add_callout(quote_text, attribution=""):
        table = doc.add_table(rows=1, cols=1)
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        table.autofit = False
        table.columns[0].width = Inches(6.5)
        cell = table.cell(0, 0)
        set_cell_background(cell, "F7F4EE")
        set_callout_border(cell, "6A1B29")
        set_cell_margins(cell, top=140, bottom=140, left=200, right=180)
        p = cell.paragraphs[0]
        p.paragraph_format.space_after = Pt(2)
        r = p.add_run(f'“{quote_text}”')
        r.font.italic = True
        r.font.size = Pt(10.5)
        r.font.color.rgb = RGBColor(60, 40, 45)
        if attribution:
            p2 = cell.add_paragraph()
            p2.alignment = WD_ALIGN_PARAGRAPH.RIGHT
            p2.paragraph_format.space_before = Pt(2)
            p2.paragraph_format.space_after = Pt(0)
            r2 = p2.add_run(f'— {attribution}')
            r2.font.size = Pt(9.5)
            r2.font.bold = True
            r2.font.color.rgb = RGBColor(140, 100, 35)
        doc.add_paragraph() # Spacing

    # ==========================================
    # COVER / HEADER TITLE
    # ==========================================
    add_title("UPRISING: THE BLOOD SACRAMENT")
    add_subtitle("Comprehensive Narrative, Character, and Worldbuilding Bible\nBio-Feudalism, Sacred Gene-Craft, and the Peasant Revolution")

    # Metadata Block
    meta_table = doc.add_table(rows=4, cols=2)
    meta_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    meta_table.columns[0].width = Inches(2.2)
    meta_table.columns[1].width = Inches(4.3)
    set_table_borders(meta_table, "E0D8C8")
    
    meta_rows = [
        ("Core Genre:", "Dark Science-Fantasy / Bio-Punk Medievalism / Narrative RPG"),
        ("Thematic Core:", "Biological Determinism vs. Human Liberation, The Weaponization of Superstition"),
        ("Geopolitical Setting:", "Alternate Feudal Europe: The French Crown & The Duchy of Breyzh"),
        ("Key Narrative Hook:", "The Disinherited Heir swapped into serfdom, whose repressed epigenetic memories ignite an empire-shattering revolution.")
    ]
    for idx, (label, val) in enumerate(meta_rows):
        c0 = meta_table.cell(idx, 0)
        c1 = meta_table.cell(idx, 1)
        set_cell_margins(c0, 60, 60, 100, 100)
        set_cell_margins(c1, 60, 60, 100, 100)
        set_cell_background(c0, "F5F1E8")
        set_cell_background(c1, "FAF8F5")
        p0 = c0.paragraphs[0]
        r0 = p0.add_run(label)
        r0.font.bold = True
        r0.font.size = Pt(9.5)
        r0.font.color.rgb = RGBColor(106, 27, 41)
        p1 = c1.paragraphs[0]
        r1 = p1.add_run(val)
        r1.font.size = Pt(9.5)
        r1.font.color.rgb = RGBColor(50, 50, 50)

    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    add_callout(
        "There is no divine right in blood—only the stolen engineering of forgotten ancestors, "
        "hoarded behind gilded altar screens and enforced by the needle.",
        "Proclamation of the Free League of Breyzh"
    )

    doc.add_page_break()

    # =========================================================================
    # PART I: PLOT PROGRESSION
    # =========================================================================
    add_h1("PART I: PLOT PROGRESSION")
    add_p(
        "The narrative of UPRISING is structured across an expansive three-act framework bookended by a tragic "
        "prologue and branching revolutionary epilogues. It charts the trajectory of a dispossessed protagonist "
        "who transitions from a chemically subjugated peasant laborer into an outlaw anomaly, an investigative insurgent, "
        "and ultimately the catalyst for a world-wide systemic revolt."
    )

    add_h2("Prologue: The Sovereign Lie & The Great Swapping")
    add_bullet(
        "In the grand court of Paris and the maritime fortress-seat of the Duchy of Breyzh, a child is born possessing an unprecedented "
        "pureblood royal genotype. This infant is the living synthesis of two apex bloodlines—the French Crown and the sovereign Breton dynasty—engineered "
        "to naturally inherit and express high-tier MAGICK without degradation across generational lines.",
        "The Dynastic Miracle: "
    )
    add_bullet(
        "Fearing that this child’s birth would tilt absolute power toward the fiercely independent Duchy of Breyzh, a clandestine faction within "
        "the French royal court, in collusion with high prelates of the Holy Church of the Sacred Flesh, orchestrates a covert usurpation. "
        "The genuine heir is quietly abducted from the royal nursery during his infancy.",
        "The Palace Conspiracy: "
    )
    add_bullet(
        "To prevent civil war and maintain the illusion of an unbroken divine line, a decoy child—sired from a noble cadet branch—is placed in the cradle. "
        "The Crown and the public are kept entirely ignorant of the swap. The decoy is raised as the legitimate prince, propped up with secret, high-grade synthetic stabilizing infusions.",
        "The Decoy Prince: "
    )
    add_bullet(
        "The infant heir is taken to an unlicensed, clandestine gene-foundry in the border marches. Rather than executing the child (risking unpredictable epigenetic fallout or religious taboo), "
        "the conspirators administer a severe neuro-chemical wipe. His emerging conscious memories are erased, artificial peasant childhood memories are synthetically embedded, "
        "and he is dumped anonymously into a wretched agrarian commune in the salt-marshes of Breyzh. "
        "Immediately afterward, Church inquisitors burn the independent medical sanctuary to ashes, exterminating the geneticists to ensure the secret dies forever.",
        "Excision and Oblivion: "
    )

    add_h2("Act I: The Yoke of Flesh (Early Game — Serfdom & The Anomaly)")
    add_bullet(
        "The protagonist grows up knowing only the grueling, sun-baked life of an unfree peasant (serf) in the peripheral fields of Breyzh. "
        "Like all commoners, he is subjected to the mandatory annual 'Tithe of Flesh': forced injections of low-grade serf MAGICK administered "
        "by itinerant Church inquisitors and noble bailiffs. The serum grants him high endurance, resistance to swamp-fever, and quick physical recovery from "
        "back-breaking toil, but deliberately numbs his higher cognitive faculties, reduces fertility, and enforces hormonal compliance.",
        "The Life of a Dosed Beast: "
    )
    add_bullet(
        "Despite repeated dosings, the hero experiences terrifying, disorienting phenomena: phantom echoes of grand marble halls, liturgical chants in classical Latin, "
        "instinctive combat reflexes during village brawls, and sudden sensory overloads. These are epigenetic fractures—ancestral memories embedded in his pureblood DNA "
        "that the serf dampeners cannot fully suppress.",
        "Fractured Echoes: "
    )
    add_bullet(
        "During a routine annual Church audit, an inquisitorial censer (a bio-detection device disguised as an incense burner) reacts violently to the hero's blood. "
        "The pureblood genome within him, destabilized by years of conflicting serf injections, violently rejects the compliance serum. In a traumatic moment of crisis, "
        "an anomalous burst of high-order kinetic and bio-electric power manifests, killing a noble bailiff and destroying the inspection altar.",
        "The Awaking Crisis: "
    )
    add_bullet(
        "Branded an unlicensed heretic and an abomination against holy bloodline doctrine, the hero is hunted by Church Auditors and armored Knight-Retainers. "
        "Rescued by desperate peasant outlaws, he is forced to flee into the wild Celtic bogs and mist-shrouded ruins of Breyzh, leaving his burning village behind.",
        "The Outlaw’s Flight: "
    )

    add_h2("Act II: The Resonant Blood (Mid Game — The Peasant Underground & The Investigation)")
    add_bullet(
        "The protagonist finds refuge with the 'Free League of Breyzh,' a desperate guerrilla insurgency composed of escaped serfs, disgraced knights, and outlawed herbalists. "
        "To survive, the hero must master his unstable, erratic abilities. The player unlocks the core gameplay hook: **Parental-Memory Psychometry**.",
        "Sanctuary in the Shadows: "
    )
    add_bullet(
        "Whenever the protagonist interacts with ancient pre-collapse ruins, noble signet relics, holy reliquaries, or royal bloodlines, his DNA resonates. "
        "He does not merely recall his own buried infancy; he experiences vivid, playable epigenetic flashbacks of his royal forebears and court conspirators. "
        "Through these traumatic visions, the player uncovers breadcrumbs of the conspiracy: court ledgers, whispers in royal bedchambers, and the identity of the masked inquisitor who ordered the laboratory purged.",
        "The Parental-Memory Investigative Mechanic: "
    )
    add_bullet(
        "The hero discovers that Prince Valeran—the celebrated heir to the French throne—is an impostor whose artificial body is rapidly decaying. "
        "To prevent his synthetic enhancements from collapsing into cancerous cellular chaos, the Crown and Church have been secretly harvesting high-grade biological tithes "
        "from enslaved subjects across Breyzh. The hero's true identity transforms from a personal enigma into an ideological crisis: he is the living, breathing proof that royal holiness is a manufactured fraud.",
        "The Gilded Deception Revealed: "
    )
    add_bullet(
        "The hero allies with Master Corvo, a fugitive pre-collapse bio-archivist surviving in the flooded subterranean catacombs beneath Rennes. "
        "Corvo synthesizes neutralizing reagents that purge the toxic serf dampeners from the hero's bloodstream, allowing his true pureblood combat mutations "
        "to bloom into terrifying, X-Men-tier sovereign power.",
        "Unlocking the True Helix: "
    )

    add_h2("Act III: The Shattered Sacrament (Late Game — The Peasant Uprising & The Bio-Revolution)")
    add_bullet(
        "The protagonist achieves full epigenetic reconstruction of his birth, childhood abduction, and memory wipe. He now possesses the biometric and epigenetic keys "
        "required to unlock the Crown's most secure, ancient pre-collapse genetic vaults in Paris and Breyzh.",
        "Full Memory Reconstruction: "
    )
    add_bullet(
        "Armed with documented laboratory logs, confiscated inquisitorial correspondence, and the undeniable testimony of his own blood, the hero confronts the Breton nobility. "
        "The Duchy of Breyzh fractures: half the nobles realize Paris betrayed them by replacing their sovereign bloodline with a synthetic French puppet, "
        "while the conservative ruling elite cling to the Church's dogma. A massive, combined insurrection of common serfs and rebel Breton clans erupts.",
        "Political Dynamite: "
    )
    add_bullet(
        "Rather than hoarding high MAGICK for himself, the hero and his rebel alchemists breach the provincial Church Gene-Foundries. "
        "They reverse-engineer the pureblood stabilization serum and distribute liberated, military-grade combat and healing mutations to the serf armies. "
        "The battlefield dynamic flips entirely: common pitchfork-wielding peasants now match the physical terror of highborn paladins and knight-retainers.",
        "The Redistribution of Flesh: "
    )
    add_bullet(
        "The allied peasant and Breton armies march upon the royal capital. The final offensive penetrates the sacred Basilica-Foundry of Saint-Denis. "
        "Here, the protagonist confronts the dying, monstrously over-dosed False Prince Valeran and the High Inquisitor who orchestrated the swap decades ago. "
        "In a climactic confrontation between distorted synthetic majesty and unyielding revolutionary power, the grand lie of the feudal order is physically shattered.",
        "The Fall of the Basilica-Foundry: "
    )

    add_h2("Epilogue: The Branching Dawn (Player Resolution)")
    add_bullet(
        "The hero destroys the Church's centralized gene-foundries and releases the uncorrupted pre-collapse genetic blueprints to all common humanity. "
        "Feudal hierarchy based on biological monopolization collapses permanently, inaugurating a tumultuous, egalitarian era of sovereign humanity.",
        "Ending A — The Free Commonwealth of Flesh (Abolitionist): "
    )
    add_bullet(
        "Claiming his rightful birthright as the legitimate sovereign of France and Breyzh, the hero ascends the throne. "
        "He uses his absolute genetic authority to reform the feudal laws, banishing involuntary serf-dosing and ruling as an enlightened bio-monarch who distributes medical grace with justice.",
        "Ending B — The Enlightened Sovereign (Reformation): "
    )
    add_bullet(
        "Realizing that genetic modification is an inescapable curse that will forever breed tyranny, the hero triggers a localized pre-collapse pathogen "
        "that neutralizes all artificial MAGICK across the realm. Knights, kings, and serfs alike are stripped of all superhuman mutations, reduced to baseline, frail mortal humans to rebuild the world on equal footing.",
        "Ending C — The Great Cleansing (The Fall of Magick): "
    )

    doc.add_page_break()

    # =========================================================================
    # PART II: CHARACTER BACKGROUNDS
    # =========================================================================
    add_h1("PART II: CHARACTER BACKGROUNDS & DRAMATIS PERSONAE")
    add_p(
        "The characters of UPRISING embody the violent contradictions of a society where biological engineering "
        "has been cloaked in theological mysticism. Their motives, conflicts, and arcs intersect directly with "
        "the questions of lineage, stolen destiny, and bodily autonomy."
    )

    add_h2("1. The Protagonist: Elian of the Mire / The Disinherited")
    add_bullet(
        "Raised as a nameless serf in the desolate salt-marshes of Breyzh. Known locally as a quiet, unusually resilient laborer who could withstand brutal swamp-malaria "
        "and sixteen-hour field shifts without physical collapse. Inside, he is plagued by nightmares of soaring stained-glass domes, gilded cradle-guards, and whispers of Latin coronation rites.",
        "Public Identity & Upbringing: "
    )
    add_bullet(
        "The legitimate son of the French Crown Prince and the Duchess of Breyzh. His genome represents the apex of pre-collapse genetic engineering: "
        "a self-stabilizing, multi-generational royal MAGICK package featuring hyper-accelerated neural pathways, rapid tissue regeneration, and epigenetic psychometry.",
        "Biological Reality: "
    )
    add_bullet(
        "Inherited from the purest royal lineages, his nervous system acts as a living archive. When exposed to ancestral genetic traces, royal relics, or intense emotional trauma, "
        "his brain decodes the epigenetic data encoded in foreign and familiar bloodlines. In gameplay, this manifests as: "
        "\n   • Epigenetic Flashbacks: Experiencing past crimes and private political meetings through the eyes of long-dead forebears."
        "\n   • Biometric Vault Decryption: Bypassing ancient pre-collapse security locks tuned exclusively to royal blood."
        "\n   • Neural Intuition: Anticipating knight combat stances and identifying biochemical poisons in food or air.",
        "The Parental-Memory Ability: "
    )
    add_bullet(
        "Elian begins as a broken, stoic serf whose only desire is to avoid the Church’s lash. As his true biology awakens, he must grapple with the sickening truth "
        "that he was born to the very class of oppressors he despises. His journey forces him to decide whether he desires vengeance, his stolen crown, or the utter dismantling of crowns altogether.",
        "Character Arc: "
    )

    add_h2("2. Prince Valeran: The Gilded Decoy / The Synthetic Heir")
    add_bullet(
        "Raised in the opulent halls of the Louvre and Versailles as the golden prodigy of France. Educated in statecraft, theology, and high chivalric warfare. "
        "Publicly revered as the living embodiment of God’s sacramental favor.",
        "Public Persona: "
    )
    add_bullet(
        "A biological counterfeit. Sired from a lesser noble cadet branch whose genome lacked natural stability, he was placed in the royal cradle as an infant. "
        "Because his body cannot naturally synthesize the royal MAGICK package, he requires excruciating bi-weekly blood transfusions and synthetic hormonal cocktails "
        "secretly harvested from conquered Breton serf populations.",
        "The Biological Rot: "
    )
    add_bullet(
        "Valeran is not a cartoon villain; he is a tragic, desperate prisoner of the lie. In his late adolescence, his body began rejecting the synthetic stabilizers, "
        "resulting in agonizing skin necrosis, tremors, and violent mood swings. He lives in mortal terror of the upcoming Sacramental Testing Rite, "
        "knowing that if his bloodline is proven impure, the Church and Crown will quietly execute him and bury his memory.",
        "Psychological Conflict: "
    )
    add_bullet(
        "Serves as Elian’s direct thematic and physical foil. While Elian is a true king living in filth, Valeran is a dying peasant wrapped in ermine and gold.",
        "Narrative Role: "
    )

    add_h2("3. Arch-Inquisitor Morvan: The Architect of Blood Grace")
    add_bullet(
        "The supreme head of the Inquisitorial Board of Biological Purity. Cold, austere, and brilliant. Morvan is fully aware that MAGICK is not a divine miracle, "
        "but the remnants of advanced pre-collapse genetic engineering. He views technology as a cosmic fire that once annihilated human civilization.",
        "Philosophical Stance: "
    )
    add_bullet(
        "Thirty years prior, Morvan orchestrated the baby swap, the burning of the independent research sanctuary, and the chemical memory-wipe of Elian. "
        "He did not do this out of petty malice, but out of ruthless ideological utilitarianism: a combined France-Breyzh super-heir would have centralized uncontrollable personal power, "
        "shattering the delicate balance between the Church and the nobility.",
        "Role in the Conspiracy: "
    )
    add_bullet(
        "Morvan commands the Inquisitorial Auditors and the specialized 'Cleansing Choirs'—bio-enhanced inquisitors equipped with blood-testing censers, "
        "paralytic neuro-darts, and alchemical flame. He represents the immovable institutional wall that Elian's revolution must tear down.",
        "The Antagonist's Power: "
    )

    add_h2("4. Master Corvo: The Pre-Collapse Archivist")
    add_bullet(
        "A former senior scholar of the clandestine Royal Foundries who defected after refusing to participate in the forced sterilization of rebellious serfs. "
        "Now living in exile beneath the sunken catacombs of Breyzh, he operates a secret gene-sanctuary and clandestine infirmary.",
        "Identity & Background: "
    )
    add_bullet(
        "Corvo is one of the few living mortals who preserves true scientific language. While the Church speaks of 'Blood Grace' and 'Chrism,' Corvo speaks of "
        "'CRISPR-analogues,' 'epigenetic methylation,' and 'synaptic rewiring.' His knowledge is treated by the Inquisition as black sorcery.",
        "Scientific Heresy: "
    )
    add_bullet(
        "Acts as Elian’s intellectual mentor and bio-engineer. He develops the cellular purges that strip away Elian's serf dampeners, helps the player interpret "
        "parental-memory data fragments, and crafts the liberated gene-serums that arm the peasant resistance.",
        "Narrative Function: "
    )

    add_h2("5. Captain Maelis: The Hammer of Breyzh")
    add_bullet(
        "A fierce, charismatic leader of the Breton peasant insurgency. Her entire family was worked to death in the Crown's sulfur quarries after being dosed with "
        "hyper-metabolic labor serums that burned their hearts out by age thirty.",
        "Background & Trauma: "
    )
    add_bullet(
        "Maelis despises the nobility with absolute ideological fury. She fights not merely for lower taxes or better bread, but for the total abolition of the nobility's biological supremacy. "
        "When Elian joins the rebels, she is his fiercest protector—until she discovers that royal blood flows through his veins. Her conflict with Elian forms "
        "the emotional and political heart of the rebellion: *Can a peasant army trust a prince who claims to fight for their freedom?*",
        "Ideological Friction: "
    )

    doc.add_page_break()

    # =========================================================================
    # PART III: SETTING BACKGROUND
    # =========================================================================
    add_h1("PART III: SETTING BACKGROUND & WORLD ARCHITECTURE")
    add_p(
        "The world of UPRISING is a dark, feudo-industrial civilization built atop the ruined bones of an advanced "
        "technological civilization that collapsed centuries ago. Rather than losing technology entirely, the ruling elites "
        "and religious hierarchies successfully captured, monopolized, and re-branded advanced human biotechnology as divine mysticism."
    )

    add_h2("1. The Feudalism of the Era: The Vassalage of Flesh")
    add_p(
        "Historical feudalism was defined by land tenure, military oaths, and economic extraction. In this world, feudalism has evolved into "
        "a total biological caste system known as **The Vassalage of Flesh**."
    )
    add_bullet(
        "Nobles do not rule simply because they own castles or hereditary charters. They rule because their physical bodies are demonstrably, undeniably superior. "
        "Through generations of selective breeding and closely guarded high-grade gene-packages, an aristocrat possesses the strength of ten men, sensory perception "
        "that can hear a whisper across a courtyard, and accelerated cellular repair that shrugs off mortal blade strikes. A peasant with an iron pitchfork physically cannot "
        "slay a highborn knight in single combat. Biological disparity guarantees political stability.",
        "Biological Supremacy as Divine Right: "
    )
    add_bullet(
        "Common serfs are legally tied to the soil and bound by the annual 'Tithe of Flesh.' Once a year, itinerant Church bailiffs and inquisitorial friars visit every village. "
        "Every peasant between the ages of twelve and fifty is strapped into a baptismal iron chair and injected with the 'Gift of Honest Toil.' "
        "This serum increases muscle density, purges field-toxins, and allows serfs to labor in freezing rains and toxic bogs without falling ill. "
        "Crucially, it is engineered with genetic 'kill-switches': it does not pass to offspring, it blunts high-level strategic reasoning, suppresses emotional aggression, "
        "and causes severe metabolic collapse if a subject goes longer than fourteen months without their next church-administered dose. The peasantry is literally addicted to its own bondage.",
        "The Annual Tithe of Flesh & Chemical Serfdom: "
    )

    add_h2("2. The Holy Church of the Sacred Flesh")
    add_bullet(
        "The Church does not oppose MAGICK; it claims absolute spiritual and legal ownership over it. The official ecclesiastical doctrine teaches that after the Great Collapse "
        "(rebranded as 'The Fall of the Tower of Pride'), God withdrew grace from the world and left it only in the veins of the righteous. "
        "The pure mutations carried by kings and dukes are proclaimed to be 'Blood Grace'—tangible proof of holy election.",
        "The Doctrine of Blood Grace: "
    )
    add_bullet(
        "Any mention of 'genetics,' 'DNA,' 'mutagens,' or 'cellular biology' is classified as the supreme blasphemy of *Techno-Hubris*. "
        "Laboratories are constructed to resemble Gothic cathedrals; centrifuges and bioreactors are disguised as golden reliquaries, brass censers, and baptismal fonts; "
        "and genetic formulas are transcribed in liturgical illumination as 'Sacred Genealogies.'",
        "The Suppression of Technology: "
    )
    add_bullet(
        "The Church deploys the Holy Order of Auditors—specialized inquisitors trained in biological forensics. They guard border crossings with blood-sampling reliquaries. "
        "If a common serf or merchant displays an unlicensed mutation (such as unexpected night-vision, kinetic bursts, or natural resistance to compliance dosing), "
        "they are declared 'Flesh-Corrupt' and subjected to immediate public burning or shipped to secret Church research catacombs for vivisection.",
        "The Inquisitorial Board of Biological Purity: "
    )

    add_h2("3. Geopolitics: The French Crown vs. The Duchy of Breyzh")
    add_bullet(
        "Centered in the fortified metropolis of Paris, the Crown represents aggressive centralization and absolute bio-monarchical control. "
        "The King commands the Grand Foundries, churning out standardized Knight-Retainer packages to maintain iron discipline across the provinces. "
        "The Crown’s ultimate ambition is to assimilate all independent regional duchies into a unified, universally dosed empire.",
        "The Kingdom of France: "
    )
    add_bullet(
        "An ancient, fiercely independent maritime duchy corresponding to historical Brittany. The Breton nobility trace their lineages to pre-collapse maritime dynasties "
        "and jealously protect their unique ancestral gene-packages. Culturally distinct, speaking Celtic dialects, and maintaining independent coastal vaults, "
        "Breyzh has long resisted French assimilation. The dynastic marriage that produced the protagonist was supposed to permanently fuse France and Breyzh; "
        "the subsequent betrayal and kidnapping of the infant heir turned Breyzh into a simmering powder keg of peasant rebellion and noble resentment.",
        "The Duchy of Breyzh: "
    )
    add_bullet(
        "The border zones between France and Breyzh, devastated by ancient collapse weapons. These irradiated, chemically contaminated swamps and dead forests "
        "are shunned by Church patrols. Here, runaway serfs, outlawed bio-alchemists, and 'wild' mutant outcasts survive in fortified commune-settlements, "
        "providing the fertile soil for Elian's revolution.",
        "The Salt-Marshes & The Dead Marches: "
    )

    doc.add_page_break()

    # =========================================================================
    # PART IV: MAGICK – THE ENGINEERED FLESH
    # =========================================================================
    add_h1("PART IV: MAGICK – THE CODEX OF ENGINEERED FLESH")
    add_p(
        "MAGICK is not esoteric witchcraft or divine sorcery. It is artificially induced, highly sophisticated genetic "
        "and epigenetic mutation engineered to grant superhuman physiological, neural, and kinetic capabilities. "
        "Every single package is manufactured, graded, and policed to ensure the perpetual stability of the feudal pyramid."
    )

    add_h2("1. Core Definition & Biological Principles")
    add_bullet(
        "The human body is rewritten at the cellular, epigenetic, and chromosomal level. Depending on the purity and concentration of the mutagenic vector, "
        "it grants enhanced physical resilience, hyper-dense muscular contraction, bio-electric discharge, accelerated tissue regeneration, and heightened sensory dominance.",
        "Biochemical Foundation: "
    )
    add_bullet(
        "Unlike comic-book mutations that appear spontaneously in teenagers, MAGICK does not naturally awaken in the wild. Every active package is deliberately engineered "
        "and introduced into the subject's marrow. What uneducated serfs perceive as a 'spontaneous miracle' is invariably the delayed expression of a covert, ancient genetic intervention.",
        "Artificial Manufacturing: "
    )
    add_bullet(
        "The fundamental law of the setting is that **only Pureblood Royal Packages are self-sustaining and naturally inheritable across generations**. "
        "All lower-tier packages are engineered with genetic instability: their telomeres degrade, their epigenetic switches reset, and their enhancements fade unless "
        "artificially reinforced by regular doses. This engineered biological decay ensures that power can never be permanently inherited by commoners.",
        "The Golden Law of Inheritance: "
    )

    add_h2("2. The Stratified Hierarchy of MAGICK Packages")
    add_p("The table below outlines the five strictly regulated tiers of engineered flesh governing civilization:")

    # Table for MAGICK Packages
    pkg_table = doc.add_table(rows=6, cols=4)
    pkg_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    pkg_table.columns[0].width = Inches(1.4)
    pkg_table.columns[1].width = Inches(1.8)
    pkg_table.columns[2].width = Inches(1.8)
    pkg_table.columns[3].width = Inches(1.5)
    set_table_borders(pkg_table, "C4B8A0")

    headers = ["Tier / Package", "Biological Manifestation", "Inheritance & Dosing", "Theological & Social Status"]
    for col_idx, h_text in enumerate(headers):
        cell = pkg_table.cell(0, col_idx)
        set_cell_background(cell, "4A121A") # Deep Burgundy
        set_cell_margins(cell, 100, 100, 100, 100)
        p = cell.paragraphs[0]
        r = p.add_run(h_text)
        r.font.bold = True
        r.font.size = Pt(9)
        r.font.color.rgb = RGBColor(255, 255, 255)

    pkg_data = [
        (
            "TIER I: PUREBLOOD ROYAL\n(The Crown & Sovereign Dukes)",
            "Transcendent bio-electric manipulation, telepathic/epigenetic memory recall, sensory omni-dominance, near-instant cellular regeneration, hyper-dense skeletal weave.",
            "100% Naturally Inheritable across pure royal matings. Never requires external dosing. Self-repairing telomeres.",
            "Revered as 'God's Living Blood Grace.' The divine justification for absolute monarchy and universal sovereignty."
        ),
        (
            "TIER II: HIGH NOBLE\n(Counts, Barons, Ducal Retainers)",
            "Kinetic shockwave absorption, heightened reflexes (3x human baseline), thermal/toxin immunity, tactical cognitive speed, enhanced strength.",
            "Partially Heritable (dilutes over 2-3 generations without royal blood marriage). Requires decennial Church chrism booster.",
            "Classified as 'Sanctified Nobility.' Legitimizes land ownership, judicial lordship, and elite knightly command."
        ),
        (
            "TIER III: KNIGHT / RETAINER\n(Paladins & Castle Guards)",
            "Iron-density dermal plating, massive physical power, combat pain neutralization, extreme adrenal bursts. Prone to mid-life cardiac burnout.",
            "Non-Inheritable. Administered upon knighting via spinal bone-marrow injection. Requires annual maintenance doses.",
            "Revered as 'The Holy Arm of the Lord.' The enforcers of feudal order; socially elevated above all common peasantry."
        ),
        (
            "TIER IV: SERF / LABORER\n(Agricultural & Mining Castes)",
            "Fatigue resistance, accelerated physical labor recovery, marsh-fever immunity, chemical compliance, hormonal suppression of rage and ambition.",
            "Strictly Non-Inheritable. Must be forcibly injected every 12 months at the village altar. Deliberately stunted fertility.",
            "Preached as 'The Merciful Gift of Honest Strength.' The biological engine of economic production and feudal servitude."
        ),
        (
            "TIER V: OUTLAW / HERETICAL\n(The Hero's Anomaly & Pre-Collapse Relics)",
            "Volatile hybrid mutations: raw kinetic discharge, epigenetic psychometry, uncontrollable regenerative blooms, sensory overload.",
            "Wild, unstable, unlicensed. Produced by black-market alchemists or repressed royal blood breaking through serf dampeners.",
            "Condemned as 'Demonic Flesh' and 'Pre-Collapse Heresy.' Triggers immediate inquisitorial manhunts and public purging."
        )
    ]

    for row_idx, data_row in enumerate(pkg_data, start=1):
        bg_col = "FAF7F2" if row_idx % 2 == 1 else "F0EBE0"
        for col_idx, text_val in enumerate(data_row):
            cell = pkg_table.cell(row_idx, col_idx)
            set_cell_background(cell, bg_col)
            set_cell_margins(cell, 80, 80, 100, 100)
            p = cell.paragraphs[0]
            r = p.add_run(text_val)
            r.font.size = Pt(8.5)
            r.font.color.rgb = RGBColor(40, 40, 40)
            if col_idx == 0:
                r.font.bold = True
                r.font.color.rgb = RGBColor(106, 27, 41)

    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    add_h2("3. The Hero’s Biological Paradox: The Contaminated Sovereign")
    add_bullet(
        "Because Elian was injected with suppressive serf serums for nearly twenty years while carrying a slumbering Tier I Royal Pureblood genome, "
        "his biology is an unprecedented biological hybrid. The compliance chemicals acted like a dam holding back an ocean of genetic power. "
        "When the dam broke, his mutations expressed themselves not as polished, disciplined court magic, but as raw, violent, instinctual surges.",
        "The Volatile Fusion: "
    )
    add_bullet(
        "His royal genome permanently rewrote and mutated the serf compliance vectors. Rather than being numbed by labor serums, his body can now metabolize "
        "and repurpose *any* foreign biological compound, turning church dampeners and enemy toxins into explosive adrenaline and regenerative fuel.",
        "Metabolic Adaptation: "
    )

    doc.add_page_break()

    # =========================================================================
    # PART V: GAMEPLAY & THEMATIC INTEGRATION
    # =========================================================================
    add_h1("PART V: GAMEPLAY & THEMATIC INTEGRATION")
    add_p(
        "The worldbuilding and narrative architecture of UPRISING directly fuel its core gameplay loops, "
        "transforming lore into player agency and mechanical progression."
    )

    add_h2("1. The Parental-Memory System as an Investigative Mechanic")
    add_bullet(
        "Throughout the game world, the player discovers ancestral blood-stains, ancient sigil-stones, noble corpses, and pre-collapse terminals. "
        "Interacting with these objects triggers 'Epigenetic Resonance,' transporting the player into short, playable, sepia-toned memory sequences. "
        "The player witnesses historical events, deciphers spoken court passwords, discovers hidden laboratory blueprints, and uncovers the vulnerabilities of enemy commanders.",
        "Playable Epigenetic Flashbacks: "
    )
    add_bullet(
        "During dialogues with noble lords and church inquisitors, Elian’s sensory abilities allow the player to detect micro-tremors, elevated heartbeats, "
        "and hormone releases, piercing noble deception and exposing political conspiracies in real-time.",
        "Dialogue Deception Detection: "
    )

    add_h2("2. Biological Progression: The Mutation Skill Trees")
    add_p(
        "The player does not earn arbitrary 'experience points' to level up; progression is tied to biological synthesis and cellular liberation:"
    )
    add_bullet(
        "Focuses on kinetic discharge, command auras, bio-electric weaponry, and ancestral sensory perception. Transcendent, regal, and devastating in open combat.",
        "Tree 1 — The Royal Helix (Lineage Dominion): "
    )
    add_bullet(
        "Focuses on pain immunity, hyper-accelerated regeneration, brute unyielding muscle mass, and environmental toxin resistance. Gritty, ferocious, and relentless.",
        "Tree 2 — The Peasant Anomaly (Flesh of the Earth): "
    )
    add_bullet(
        "Focuses on biochemical brewing, crafting liberated combat serums for companion rebel fighters, utilizing pre-collapse surgical augments, and disabling church sensors.",
        "Tree 3 — The Heretic Scholar (Bio-Alchemical Artifice): "
    )

    add_h2("3. Core Thematic Pillars")
    add_bullet(
        "The game challenges the fantasy trope of 'the chosen prince reclaiming his throne.' Elian is indeed the rightful prince, but his experience as a brutalized serf "
        "forces him to confront whether any human being should hold biological sovereignty over another. Reclaiming the throne is an option, but smashing the throne entirely is the true revolutionary question.",
        "The Illusion of Divine Birthright: "
    )
    add_bullet(
        "The Church and Crown weaponized scientific ignorance to transform biological engineering into celestial liturgy. The revolution succeeds not merely by the sword, "
        "but by education—by teaching common serfs that their oppressors are not gods, but men with syringes.",
        "Superstition as an Instrument of Enslavement: "
    )
    add_bullet(
        "Every combat encounter, story beat, and ethical dilemma revolves around who controls the human body. From forced church injections to illegal rebel gene-dosing, "
        "the ultimate battle is for the freedom of the flesh.",
        "Bodily Sovereignty: "
    )

    # Document Finalization
    output_path = r"c:\Projects\uprising-game\Uprising_Game_Backstory_and_World_Bible.docx"
    doc.save(output_path)
    print(f"Document successfully created and saved to: {output_path}")

if __name__ == '__main__':
    create_document()
