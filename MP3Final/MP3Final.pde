import controlP5.*;
import ddf.minim.*;

import java.util.*;
import java.net.InetAddress;
import javax.swing.*;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;

import org.elasticsearch.action.admin.indices.exists.indices.IndicesExistsResponse;
import org.elasticsearch.action.admin.cluster.health.ClusterHealthResponse;
import org.elasticsearch.action.index.IndexRequest;
import org.elasticsearch.action.index.IndexResponse;
import org.elasticsearch.action.search.SearchResponse;
import org.elasticsearch.action.search.SearchType;
import org.elasticsearch.client.Client;
import org.elasticsearch.common.settings.Settings;
import org.elasticsearch.node.Node;
import org.elasticsearch.node.NodeBuilder;

// Constantes para referir al nombre del indice y el tipo
static String INDEX_NAME = "canciones";
static String DOC_TYPE = "cancion";

ControlP5 cp5, bt, sli;
ScrollableList list;
Client client;
Node node;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;
Minim minim;
int H, L, B;
float value=1;
String path="";
boolean select,select2=false;
AudioPlayer song;
AudioMetaData meta;
HighPassSP highP;
LowPassSP lowP;
BandPass band;

void setup() {
  size(1000, 600);
  bt= new ControlP5(this);
  PImage pl= loadImage("play.png");
  bt.addButton("Play").setPosition(10, 500).setSize(25, 25).setImage(pl);
  bt=new ControlP5(this);
  PImage st= loadImage("stop.png");
  bt.addButton("Stop").setPosition(170, 500).setSize(25, 25).setImage(st);
  bt=new ControlP5(this);
  PImage pa= loadImage("pause.png");
  bt.addButton("Pause").setPosition(90, 500).setSize(25, 25).setImage(pa);
  bt=new ControlP5(this);
  PImage su= loadImage("subir.png");
  bt.addButton("Subir").setPosition(350, 500).setSize(25, 25).setImage(su);
  bt=new ControlP5(this);
  PImage ba= loadImage("bajar.png");
  bt.addButton("Bajar").setPosition(430, 500).setSize(25, 25).setImage(ba);
  
  
  sli=new ControlP5(this);
  sli.addSlider("H").setPosition(width-180, height-130).setSize(25, 100).setRange(1000, 14000).setValue(1000).setNumberOfTickMarks(50);
  sli.addSlider("L").setPosition(width-150, height-130).setSize(25, 100).setRange(3000, 30000).setValue(3000).setNumberOfTickMarks(50);
  sli.addSlider("B").setPosition(width-120, height-130).setSize(25, 100).setRange(100, 900).setValue(100).setNumberOfTickMarks(50);
  sli.getController("H").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(100);
  sli.getController("L").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(100);
  sli.getController("B").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(100);
  minim = new Minim(this);  
  cp5 = new ControlP5(this);
  // Configuracion basica para ElasticSearch en local
  Settings.Builder settings = Settings.settingsBuilder();
  // Esta carpeta se encontrara dentro de la carpeta del Processing
  settings.put("path.data", "esdata");
  settings.put("path.home", "/");
  settings.put("http.enabled", false);
  settings.put("index.number_of_replicas", 0);
  settings.put("index.number_of_shards", 1);

  // Inicializacion del nodo de ElasticSearch
  node = NodeBuilder.nodeBuilder()
    .settings(settings)
    .clusterName("mycluster")
    .data(true)
    .local(true)
    .node();

  // Instancia de cliente de conexion al nodo de ElasticSearch
  client = node.client();

  // Esperamos a que el nodo este correctamente inicializado
  ClusterHealthResponse r = client.admin().cluster().prepareHealth().setWaitForGreenStatus().get();
  println(r);

  // Revisamos que nuestro indice (base de datos) exista
  IndicesExistsResponse ier = client.admin().indices().prepareExists(INDEX_NAME).get();
  if (!ier.isExists()) {
    // En caso contrario, se crea el indice
    client.admin().indices().prepareCreate(INDEX_NAME).get();
  }

  // Agregamos a la vista un boton de importacion de archivos
  cp5.addButton("importFiles")
    .setPosition(200, 10)
    .setLabel(" Importar archivos ");

  // Agregamos a la vista una lista scrollable que mostrara las canciones
  list = cp5.addScrollableList("playlist")
    .setPosition(0, 40)
    .setSize(500, 400)
    .setBarHeight(20)
    .setItemHeight(20)
    .setType(ScrollableList.LIST);

  // Cargamos los archivos de la base de datos
  loadFiles();
}
void fileSelected() {
  if (select2) {
    song = minim.loadFile(path, 1024);
    meta = song.getMetaData();
    highP = new HighPassSP(300, song.sampleRate());
    song.addEffect(highP);
    lowP = new LowPassSP(300, song.sampleRate());
    song.addEffect(lowP);
    band = new BandPass(300, 300, song.sampleRate());
    song.addEffect(band);
    select = true;
    println("Window was closed or the user hit cancel. ");
  }
}

void draw() {
  background(loadImage("fondo.jpg"));
  if (select) {
    highP.setFreq(H);
    lowP.setFreq(L);
    band.setFreq(B);
    fill(#0000FF);
    textSize(18);
    text("  ESTAS ESCUCHANDO: ", 50, 370);
    text("Titulo:   "+meta.title(), 50, 400);
    text("Interprete:   "+meta.author(), 50, 430);
    for ( int i = 0; i < song.bufferSize() - 1; i++ ) {
      float x1 = map(i, 0, song.bufferSize(), 0, width);
      float x2 = map(i+1, 0, song.bufferSize(), 0, width);
      line(x1, height/6 - song.left.get(i)*50, x2, height/6 - song.left.get(i+1)*75);
      line(x1, 3*height/6 - song.right.get(i)*50, x2, 3*height/6 - song.right.get(i+1)*75);
    }
  }
}

void importFiles() {
  // Selector de archivos
  JFileChooser jfc = new JFileChooser();
  // Agregamos filtro para seleccionar solo archivos .mp3
  jfc.setFileFilter(new FileNameExtensionFilter("MP3 File", "mp3"));
  // Se permite seleccionar multiples archivos a la vez
  jfc.setMultiSelectionEnabled(true);
  // Abre el dialogo de seleccion
  jfc.showOpenDialog(null);

  // Iteramos los archivos seleccionados
  for (File f : jfc.getSelectedFiles()) {
    // Si el archivo ya existe en el indice, se ignora
    GetResponse response = client.prepareGet(INDEX_NAME, DOC_TYPE, f.getAbsolutePath()).setRefresh(true).execute().actionGet();
    if (response.isExists()) {
      continue;
    }

    // Cargamos el archivo en la libreria minim para extrar los metadatos
    Minim minim = new Minim(this);
    AudioPlayer song = minim.loadFile(f.getAbsolutePath());
    AudioMetaData meta = song.getMetaData();

    // Almacenamos los metadatos en un hashmap
    Map<String, Object> doc = new HashMap<String, Object>();
    doc.put("author", meta.author());
    doc.put("title", meta.title());
    doc.put("path", f.getAbsolutePath());

    try {
      // Le decimos a ElasticSearch que guarde e indexe el objeto
      client.prepareIndex(INDEX_NAME, DOC_TYPE, f.getAbsolutePath())
        .setSource(doc)
        .execute()
        .actionGet();

      // Agregamos el archivo a la lista
      addItem(doc);
    } 
    catch(Exception e) {
      e.printStackTrace();
    }
  }
}

// Al hacer click en algun elemento de la lista, se ejecuta este metodo
void playlist(int n) {
  Map<String, Object> value = (Map<String, Object>) list.getItem(n).get("value");
  println(value.get("path"));
  path =(value.get("path").toString());
  select2=true;
  fileSelected();
  
}

void loadFiles() {
  try {
    // Buscamos todos los documentos en el indice
    SearchResponse response = client.prepareSearch(INDEX_NAME).execute().actionGet();

    // Se itera los resultados
    for (SearchHit hit : response.getHits().getHits()) {
      // Cada resultado lo agregamos a la lista
      addItem(hit.getSource());
    }
  } 
  catch(Exception e) {
    e.printStackTrace();
  }
}

// Metodo auxiliar para no repetir codigo
void addItem(Map<String, Object> doc) {
  // Se agrega a la lista. El primer argumento es el texto a desplegar en la lista, el segundo es el objeto que queremos que almacene
  list.addItem(doc.get("author") + " - " + doc.get("title"), doc);
}
public void Play() {
  song.play();
  println("Play");
}
public void Stop() {
  song.pause();
  song.rewind();
  println("Stop");
}
public void Pause() {
  song.pause();
  println("Pause");
}
public void Subir() {
  value=value+5;
  song.setGain(value);
  println("Subir");
}
public void Bajar() {
  value=value-5;
  song.setGain(value);
  println("Bajar");
}
public void Abrir() {
  select=false;
  selectInput("Selecciona un archivo: ", "fileSelected");
}