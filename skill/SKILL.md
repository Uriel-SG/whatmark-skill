---
name: whatmark
description: Esperimento comparativo su comunicazione tra Claude Code e altro modello linguistico locale che lavora in collaborazione, in questo caso per la traduzione di un testo.
---

# Translation Lab

Esperimento controllato: **lo stesso contenuto, due percorsi diversi**

- **Percorso A** — il testo scritto direttamente nella lingua target.
- **Percorso B** — il testo scritto in una lingua diversa dalla lingua target (se la lingua target NON è l'inglese, l'inglese viene scelto di default), poi tradotto da un modello locale (Ollama) nella stessa lingua target.

L'output sono i due testi nella lingua target e **l'analisi della loro differenza**.

## Prerequisiti

Ollama in esecuzione con almeno un modello. Verifica prima di partire:

```bash
curl -s http://127.0.0.1:11434/api/tags
```

Se non risponde: avvia Ollama. Se manca il modello: `ollama pull mistral`.
Non installare nulla senza chiedere conferma all'utente.

## Percorsi e interprete

Gli script stanno nella cartella `scripts/` **di questa skill**, non nella
directory di lavoro dell'utente. Risolvi il percorso assoluto della skill
prima di eseguirli e usalo in tutti i comandi.

L'interprete cambia per sistema operativo:
- Windows: `py`
- macOS / Linux: `python3`

Negli esempi sotto, `<SKILL>` sta per il percorso assoluto di questa cartella
e `<PY>` per l'interprete corretto.

## Procedura

### 1. Concorda il contenuto

Utilizzando come lingua l'inglese, chiedi all'utente argomento, lunghezza indicativa e lingua target. L'argomento può anche specificarlo in autonomia all'inizio della richiesta.
Il contenuto deve essere **identico nei due percorsi**: è l'unica variabile
che va tenuta ferma perché l'esperimento abbia senso.

Scrivi un brief di 2-3 righe e fattelo confermare. Quel brief verrà usato
alla lettera per entrambi i percorsi.

Una volta concordato il brief, salvalo come `brief.txt` nella cartella scelta come cartella di ouput generale, ossia `C:\ClaudeText` per Windows e `~/ClaudeText` per Linux/macOS. Se non esiste, creala.

Inoltre, dopo le scelte e la conferma dell'utente sulle scelte effettuate, non chiedere più conferme ed esegui i comandi relativi all'obiettivo da raggiungere (traduzione e salvataggio dei file nella cartella indicata) senza ulteriori interazioni con l'utente.

### 2. Percorso A — scrittura diretta

Scrivi il testo nella lingua target, seguendo il brief.
Salvalo come `A_direct.txt` nella cartella usata come output generale.

### 3. Percorso B — inglese, poi traduzione

Scrivi lo **stesso** contenuto in inglese, dallo stesso brief.
Salvalo in `B_source_en.txt` nella medesima cartella.

Poi traducilo con il modello locale:

```bash
<PY> "<SKILL>/scripts/ollama_translate.py" B_source_en.txt \
    -o B_translated.txt --target italiano --model mistral
```

### 4. Analisi

```bash
<PY> "<SKILL>/scripts/compare_texts.py" A_direct.txt B_translated.txt \
    --labels "Diretto" "Tradotto"
```

Aggiungi `--json` se serve l'output grezzo per elaborazioni successive.

### 5. Interpreta i numeri

Non limitarti a stampare la tabella. Commenta cosa dicono i valori:

| Metrica | Cosa rivela |
|---|---|
| **Jaccard unigrammi** | quanto vocabolario condividono. Alto = il traduttore ha scelto parole diverse |
| **Jaccard bi/trigrammi** | quanto è cambiata la *sintassi*. Cresce sempre rispetto agli unigrammi: se cresce molto, il traduttore ha ricostruito le frasi, non solo sostituito parole |
| **type-token ratio** | ricchezza lessicale. Un calo nel tradotto = appiattimento del vocabolario |
| **lungh. media frase** | i traduttori tendono ad allungare (esplicitano ciò che l'originale lasciava implicito) |
| **dev.std lungh. frase** | varietà di ritmo. Un calo = prosa più monotona |
| **anglicismi tecnici** | quanti termini inglesi il traduttore ha (impropriamente) tradotto. Nel dominio IT è l'indicatore più diagnostico |
| **lessico esclusivo** | mostra le *scelte* del traduttore. È la parte più leggibile a occhio |

### 6. Riporta

Presenta all'utente la tabella, poi un commento di qualche riga su:
- dove il traduttore ha perso registro o precisione
- quali termini tecnici ha tradotto quando non doveva
- se la struttura in paragrafi ha retto
- il verdetto qualitativo: quale dei due testi è migliore, e perché
e salva l'ouput come file di testo chiamato report.txt nella stessa cartella in cui si trovano gli altri output.


## Varianti interessanti (OPZIONALI solo se specificato dagli utenti)

- **Modelli a confronto**: stesso `B_source_en.txt`, tradotto da modelli
  diversi (`--model mistral`, `--model llama3.2`, `--model qwen2.5`).
  Confronta le traduzioni fra loro: emergono i tic di ciascun modello.
- **Effetto temperatura**: stessa traduzione a `--temperature 0.1` e `0.9`.
- **Stabilità**: traduci due volte con gli stessi parametri e confronta i due
  output. La divergenza residua misura il rumore di sampling.
- **Round-trip**: IT → EN → IT e confronta con l'originale italiano. Misura
  quanto significato sopravvive a un giro completo.

## Note

Gli script usano solo la stdlib di Python 3.10+. Nessuna dipendenza.
Su Windows usa `py` al posto di `python3`.
`ollama_translate.py` parla con l'API HTTP di Ollama su `127.0.0.1:11434`;
non serve alcun SDK, è una POST con payload JSON.
