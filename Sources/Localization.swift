// Traduzioni. Le chiavi sono quelle di mas/l10n.json: da lì nascono, per ogni lingua,
// Resources/<lingua>.lproj/Localizable.strings e InfoPlist.strings (quest'ultimo lo legge
// macOS da solo, per il testo del permesso audio — non passa da qui).
//
// Aggiungere una stringa: si mette la chiave in mas/l10n.json, si lancia
// `python3 mas/l10n.py gen`, poi la si usa nel codice con L("chiave").

import Foundation

/// La stringa nella lingua dell'utente. Se la chiave non esiste il bundle restituisce la chiave
/// stessa: si vede subito nel menu, invece di una voce vuota che non si capisce da dove viene.
/// `python3 mas/l10n.py check` controlla che ogni chiave usata qui sia anche in l10n.json.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
