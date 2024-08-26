Descrierea Implementarii:

    Pentru rezolvarea acestei teme am ales o implementare care se
bazează pe linear probing. Având în vedere că am avut de implementat
un hashtable, care se bazează pe o relație de keys -> hashes, am 
folosit o structură de tipul pair în implementarea mea.

    Pentru implementarea constructorului, am inițializat tabela de
dispersie cu un anumit size, urmând ca după să aloc memorie pentru
array-ul entries folosind glbGpuAllocator->_cudaMallocManaged iar
la final seteaz toate intrările în tabela de dispersie la zero 
folosind comanda cudaMemset. Iar pentru implementarea destructorului
elibereaz memoria alocată pentru array-ul entries folosind comanda 
glbGpuAllocator->_cudaFree.

    Pentru implementarea funcției Reshape am început prin a redimensiona
tabela de dispersie pe baza unui număr specificat de bucket-uri, urmând
ca după să aloc memorie pentru un nou array entries cu noua dimensiune
folosind glbGpuAllocator->_cudaMallocManaged, seteaz toate intrările 
în noua tabelă de dispersie la zero folosind cudaMemset, transfer 
intrările existente din tabela veche în noua tabelă de dispersie
folosind kernelul device_reshape iar la final libereaz memoria 
alocată pentru vechiul array entries folosind comanda 
glbGpuAllocator->_cudaFree. De asemenea, am folosit o funcție extra
și anume device_reshape pentru implementarea funcției, care este
o funcție kernel executată pe GPU care redimensionează tabela
de dispersie prin transferul intrărilor din tabela veche în tabela nouă.
În această funcție fiecare thread este responsabil de procesarea
unei singure intrări în tabela veche. Aceasta alculează valoarea hash
pentru cheia intrării pe baza noii dimensiuni ale tabelei de dispersie,
utilizează sondajul liniar pentru a gestiona coliziunile și găsirea
unui slot gol în noua tabelă de dispersie și nu în ultimul rând
actualizează atomic perechea key-hash în noua tabelă de dispersie
folosind atomicCAS pentru a asigura siguranța firelor de execuție.

    Funcția InsertBatch, după cum ne putem da seama din nume
inserează un lot de perechi key-hash în tabela de dispersie. Aceasta
verifică dacă factorul de încărcare al tabelei de dispersie depășește
o anumită limită care a fost setată la 0.8 și declanșează operația
de redimensionare a tabelei în caz afirmativ, redimensionând-o la 1.5.
Această funcție alocă memorie pe GPU pentru array-ul de chei,
array-ul valori și pentru un array auxiliar de chei introduse
(insertedKeys) utilizând glbGpuAllocator->_cudaMalloc, transferă
array-ul de chei și array-ul de valori de la CPU la GPU utilizând
comanda cudaMemcpy, execută funcția de kernel insertKernel pentru
a insera efectiv perechile cheie-valoare în tabela de dispersie,
sincronizează GPU-ul pentru a asigura finalizarea tuturor operațiilor,
actualizează numărul de chei introduse (insertedKeys) pe baza
array-ului insertedKeys, eliberează memoria alocată pe GPU utilizând
comanda glbGpuAllocator->_cudaFree și într-un final returnează o
valoare booleană care indică succesul operației de inserție. Această
funcție, precum funcția anterioară de reshape, folosește o funcție
auxiliară de kernel și anume funcția Insert. Această funcție inserează
o singură pereche key-hash în tabela de dispersie, calculează valoarea
hash pentru cheie utilizând dimensiunea tabelei de dispersie și
determină poziția de inserare în tabelă. De asemenea aceasta utilizează
liniar probing pentru a găsi un slot gol în cazul în care poziția
calculată este deja ocupată, actualizează atomic perechea key-hash
în tabelă utilizând atomicCAS pentru a asigura siguranța firelor
de execuție iar dacă inserarea reușește, returnează true.
    Într-un final, funcția am implementat funcția GrtBatch. Această
funcție returnează un array de valori asociate unui lot de chei
din tabela de dispersie, verifică dacă numărul de chei din lot
este nul și returnează nullptr în acest caz, alocă memorie pe
GPU pentru array-ul de chei și array-ul de valori utilizând
comanda glbGpuAllocator->_cudaMallocManaged și transferă array-ul
de chei de la CPU la GPU utilizând comanda cudaMemcpy. După aceea
execută funcția de kernel deviceGet pentru a obține valorile
corespunzătoare cheilor din tabela de dispersie, sincronizează 
GPU-ul pentru a asigura finalizarea tuturor operațiilor, transferă
array-ul de valori de la GPU la CPU utilizând comanda cudaMemcpy,
eliberează memoria alocată pe GPU utilizând comanda
glbGpuAllocator->_cudaFree și într-un final returnează un array
de valori asociate lotului de chei. Precum deja am făcut la majoritatea
funcțiilor, am utilizat o funcție de kernel auxiliară și anume funcția
Get care returnează valoarea asociată unei chei specifice în tabela
de dispersie. Aceasta calculează valoarea hash pentru cheie utilizând
dimensiunea tabelei de dispersie și determină poziția corespunzătoare
în tabelă utilizând linear probing pentru a căuta cheia în cazul în
care poziția calculată nu corespunde cheii căutate și în final returnează
valoarea asociată cheii dacă aceasta este găsită în tabelă.


Rezultate rulare:

------- Test T1 START ----------

HASH_BATCH_INSERT count: 500000 speed: 114M/sec loadfactor: 66%
HASH_BATCH_INSERT count: 500000 speed: 84M/sec loadfactor: 88%
HASH_BATCH_GET count: 500000 speed: 186M/sec loadfactor: 59%
HASH_BATCH_GET count: 500000 speed: 182M/sec loadfactor: 59%
----------------------------------------------
AVG_INSERT: 99 M/sec, AVG_GET: 184 M/sec, MIN_SPEED_REQ: 0 M/sec


------- Test T1 END ---------- [ OK RESULT: 15 pts ]

Total so far: 15 / 80



------- Test T2 START ----------

HASH_BATCH_INSERT count: 1000000 speed: 121M/sec loadfactor: 66%
HASH_BATCH_INSERT count: 1000000 speed: 88M/sec loadfactor: 88%
HASH_BATCH_GET count: 1000000 speed: 197M/sec loadfactor: 59%
HASH_BATCH_GET count: 1000000 speed: 227M/sec loadfactor: 59%
----------------------------------------------
AVG_INSERT: 105 M/sec, AVG_GET: 212 M/sec, MIN_SPEED_REQ: 20 M/sec


------- Test T2 END ---------- [ OK RESULT: 15 pts ]

Total so far: 30 / 80



------- Test T3 START ----------

HASH_BATCH_INSERT count: 1000000 speed: 122M/sec loadfactor: 66%
HASH_BATCH_INSERT count: 1000000 speed: 89M/sec loadfactor: 88%
HASH_BATCH_INSERT count: 1000000 speed: 74M/sec loadfactor: 88%
HASH_BATCH_INSERT count: 1000000 speed: 74M/sec loadfactor: 79%
HASH_BATCH_GET count: 1000000 speed: 223M/sec loadfactor: 79%
HASH_BATCH_GET count: 1000000 speed: 219M/sec loadfactor: 79%
HASH_BATCH_GET count: 1000000 speed: 218M/sec loadfactor: 79%
HASH_BATCH_GET count: 1000000 speed: 199M/sec loadfactor: 79%
----------------------------------------------
AVG_INSERT: 90 M/sec, AVG_GET: 215 M/sec, MIN_SPEED_REQ: 40 M/sec


------- Test T3 END ---------- [ OK RESULT: 15 pts ]

Total so far: 45 / 80



------- Test T4 START ----------

HASH_BATCH_INSERT count: 20000000 speed: 129M/sec loadfactor: 66%
HASH_BATCH_INSERT count: 20000000 speed: 95M/sec loadfactor: 88%
HASH_BATCH_INSERT count: 20000000 speed: 80M/sec loadfactor: 88%
HASH_BATCH_INSERT count: 20000000 speed: 80M/sec loadfactor: 79%
HASH_BATCH_GET count: 20000000 speed: 284M/sec loadfactor: 79%
HASH_BATCH_GET count: 20000000 speed: 277M/sec loadfactor: 79%
HASH_BATCH_GET count: 20000000 speed: 277M/sec loadfactor: 79%
HASH_BATCH_GET count: 20000000 speed: 246M/sec loadfactor: 79%
----------------------------------------------
AVG_INSERT: 96 M/sec, AVG_GET: 271 M/sec, MIN_SPEED_REQ: 50 M/sec


------- Test T4 END ---------- [ OK RESULT: 15 pts ]

Total so far: 60 / 80



------- Test T5 START ----------

HASH_BATCH_INSERT count: 50000000 speed: 137M/sec loadfactor: 66%
HASH_BATCH_INSERT count: 50000000 speed: 96M/sec loadfactor: 88%
HASH_BATCH_GET count: 50000000 speed: 282M/sec loadfactor: 59%
HASH_BATCH_GET count: 50000000 speed: 277M/sec loadfactor: 59%
----------------------------------------------
AVG_INSERT: 116 M/sec, AVG_GET: 279 M/sec, MIN_SPEED_REQ: 50 M/sec


------- Test T5 END ---------- [ OK RESULT: 10 pts ]

Total so far: 70 / 80



------- Test T6 START ----------

HASH_BATCH_INSERT count: 10000000 speed: 132M/sec loadfactor: 66%
HASH_BATCH_INSERT count: 10000000 speed: 94M/sec loadfactor: 88%
HASH_BATCH_INSERT count: 10000000 speed: 80M/sec loadfactor: 88%
HASH_BATCH_INSERT count: 10000000 speed: 81M/sec loadfactor: 79%
HASH_BATCH_INSERT count: 10000000 speed: 71M/sec loadfactor: 65%
HASH_BATCH_INSERT count: 10000000 speed: 116M/sec loadfactor: 79%
HASH_BATCH_INSERT count: 10000000 speed: 61M/sec loadfactor: 61%
HASH_BATCH_INSERT count: 10000000 speed: 127M/sec loadfactor: 70%
HASH_BATCH_INSERT count: 10000000 speed: 114M/sec loadfactor: 79%
HASH_BATCH_INSERT count: 10000000 speed: 46M/sec loadfactor: 58%
HASH_BATCH_GET count: 10000000 speed: 282M/sec loadfactor: 58%
HASH_BATCH_GET count: 10000000 speed: 276M/sec loadfactor: 58%
HASH_BATCH_GET count: 10000000 speed: 277M/sec loadfactor: 58%
HASH_BATCH_GET count: 10000000 speed: 276M/sec loadfactor: 58%
HASH_BATCH_GET count: 10000000 speed: 277M/sec loadfactor: 58%
HASH_BATCH_GET count: 10000000 speed: 275M/sec loadfactor: 58%
HASH_BATCH_GET count: 10000000 speed: 271M/sec loadfactor: 58%
HASH_BATCH_GET count: 10000000 speed: 272M/sec loadfactor: 58%
HASH_BATCH_GET count: 10000000 speed: 276M/sec loadfactor: 58%
HASH_BATCH_GET count: 10000000 speed: 262M/sec loadfactor: 58%
----------------------------------------------
AVG_INSERT: 92 M/sec, AVG_GET: 274 M/sec, MIN_SPEED_REQ: 50 M/sec


------- Test T6 END ---------- [ OK RESULT: 10 pts ]

Total so far: 80 / 80

Total: 80 / 80

Scurtă discuție a rezultatelor:
    Rezultatele le-am luat direct de pe moodle, ca să fiu sigur
că primeam punctele și pe moodle, dar uneori posibil din cauza
trimiterii unui număr foarte mare de teme în timp foarte scurt
primesc mai puține puncte pe moodle decât ar trebui și decât
primesc pe hpsl.

    AVG_INSERT reprezintă viteza medie de inserare, AVG_GET 
reprezintă viteza medie de obținere (get) a elementelor iar 
MIN_SPEED_REQ reprezintă viteza minimă necesară pentru
ca testul să fie considerat un succes. Observăm că în 
majoritatea testelor, viteza medie de inserare și de get
se situează în jurul valorilor de 90-120 M/sec și
210-280 M/sec, respectiv, iar valoarea MIN_SPEED_REQ crește
aproape constant.