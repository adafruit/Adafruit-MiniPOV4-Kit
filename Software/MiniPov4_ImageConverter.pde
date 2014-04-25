/*
Image Converter for MiniPOV4
by Frank Zhao

requires Processing 2.0, and the library controlP5 2.0.4 (or later) to be installed
also requires avrdude 5.11 or later, installed somewhere that can be called directly

version 201306111447:
  * 8 bit shading added
  * fixed image disappearing upon resize
  * TODO: implement size limit, I am waiting for the hardware to be finalized
version 201306101727:
  * no upscaling from images smaller than 80pix high
version 201306101542:
  * almost all basic functionality works
  * shading not supported, so 3 bit color only
  
*/

import controlP5.*;
import javax.swing.*; 
import javax.swing.filechooser.*;
import java.awt.image.*;
import javax.imageio.*;
import java.io.*;
import java.util.prefs.*;
import java.awt.event.*;

ControlP5 cp5;
Preferences prefs;
boolean cp5_isReady = false;
PImage img1, img2;
int imgW;
boolean need_redraw = false;

void setup()
{
  // helps the file dialogs remember the last directory
  prefs = Preferences.userNodeForPackage(this.getClass());
  
  // this makes the file dialogs look pretty
  try { 
    UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName()); 
  } catch (Exception e) { 
    e.printStackTrace();
  } 

  size(800, 190);
  if (frame != null) {
    frame.setResizable(true);
  }
  
  background(0, 0, 0);
  
  cp5 = new ControlP5(this);
  
  int x = 10;
  int yStart = 10;
  int ySpace = 20;
  int w = 120;
  
  cp5.addButton("openImg")
   .setLabel("Open Image File")
   .setValue(0)
   .setPosition(x, yStart + (ySpace * 0))
   .setSize(w, ySpace - 1)
   ;
   
  cp5.addButton("saveBin")
   .setLabel("Save as BIN File")
   .setValue(0)
   .setPosition(x, yStart + (ySpace * 1))
   .setSize(w, ySpace - 1)
   ;
   
  cp5.addButton("openBin")
   .setLabel("Open BIN File")
   .setValue(0)
   .setPosition(x, yStart + (ySpace * 2))
   .setSize(w, ySpace - 1)
   ;
   
  cp5.addButton("download")
   .setLabel("Download to MiniPOV4")
   .setValue(0)
   .setPosition(x, yStart + (ySpace * 3))
   .setSize(w, ySpace - 1)
   ;
  
  println("ready");
  
  // this version of controlP5 seems to call the events when the buttons are created, so I have a flag here to prevent that
  cp5_isReady = true;
  
  // resizing the window seems to erase the image, so we detect this event and redraw later 
  frame.addComponentListener(new ComponentAdapter()
  {
    public void componentResized(ComponentEvent e)
    {
      if(e.getSource() == frame) {
        need_redraw = true;
      }
    }
  }); 
}

void draw()
{
  if (need_redraw) {
    // resizing the window seems to erase the image, so we detect this event and redraw later
    if (img1 != null) image(img1, 10 + 120 + 10, 10);
    if (img2 != null) image(img2, 10 + 120 + 10, 10 + 80 + 10);
    need_redraw = false;
  }
}

// this mode only supports 3 bit, so only on and off for each color
color colorDownConvert3(color c)
{
  // extract the individual channels
  int cred = c >> 16 & 0xFF;
  int cgreen = c >> 8 & 0xFF;
  int cblue = c >> 0 & 0xFF;
  
  // do color conversion here
  if (cred > 0x7F) cred = 0xFF; else cred = 0x00;
  if (cgreen > 0x7F) cgreen = 0xFF; else cgreen = 0x00;
  if (cblue > 0x7F) cblue = 0xFF; else cblue = 0x00;
        
  return color(cred, cgreen, cblue);
}

// this mode supports 8 bit shading
color colorDownConvert8(color c)
{
  // extract the individual channels
  int cred = c >> 16 & 0xFF;
  int cgreen = c >> 8 & 0xFF;
  int cblue = c >> 0 & 0xFF;
  
  // do color conversion here
 cred = cred & 0xE0;
 cgreen = cgreen & 0xE0;
 cblue = cblue & 0xC0;
 if (cred == 0xE0) cred = 0xFF;
 if (cgreen == 0xE0) cgreen = 0xFF;
 if (cblue == 0xC0) cblue = 0xFF;
        
  return color(cred, cgreen, cblue);
}

color colorDownConvert(color c)
{
  // change the default conversion mode here
  return colorDownConvert8(c);
}

byte colorToByte(color c)
{
  // extract the individual channels
  int cred = c >> 16 & 0xFF;
  int cgreen = c >> 8 & 0xFF;
  int cblue = c >> 0 & 0xFF;
  
  byte b = 0;
  
  b += cred & 0xE0;
  b += cgreen >> 3 & 0x1C;
  b += cblue >> 6 & 0x03;
  
  return b;
}

color byteToColor(byte b)
{
  int cred, cgreen, cblue;
  cred = b & 0xE0;
  if (cred >= 0xE0) cred = 0xFF;
  cgreen = (b & 0x1C) << 3;
  if (cgreen >= 0xE0) cgreen = 0xFF;
  cblue = (b & 0x03) << 6;
  if (cblue >= 0xC0) cblue = 0xFF;  
  return color(cred, cgreen, cblue);
}

public void openImg(int val)
{
  if (!cp5_isReady) return;
  
  println("openImg clicked");
  
  final JFileChooser fc = new JFileChooser(); 
  println("Chooser");
  
  try {
    fc.setCurrentDirectory(new File(prefs.get("LAST_FILECHOOSER_DIR", "")));
    println("set CD");
  } catch (Exception e) { 
    e.printStackTrace();
  }
  
  fc.addChoosableFileFilter(new FileNameExtensionFilter("Image Files", ImageIO.getReaderFileSuffixes()));
  println("ChoosableFilter");
  
  if (fc.showOpenDialog(this) == JFileChooser.APPROVE_OPTION)
  {
      println("Approved");
    String fp = fc.getSelectedFile().getPath();
    println("file: " + fp);
    
    prefs.put("LAST_FILECHOOSER_DIR", fc.getSelectedFile().getParent());
    
    background(0);
    
    try {
      // generate preview
      img1 = loadImage(fp);
      int w, h;
      w = img1.width;
      h = img1.height;
      float scale = 80.0f / h;
      int nw = round(w * scale);
      if (scale < 1.0f) {
        img1.resize(nw, 80);
      }
      image(img1, 10 + 120 + 10, 10);
      
      // down convert to 8 pixel high
      PImage si = loadImage(fp);
      scale = 8.0f / h;
      imgW = round(w * scale);
      si.resize(imgW, 8);
      si.loadPixels();
      img2 = new PImage(nw, 80);
      
      // convert for preview
      for (int x = 0; x < nw; x++)
      {
        for (int y = 0; y < 80; y++)
        {
          color c = si.get(floor(x / 10.0f), floor(y / 10.0f));        
          img2.set(x, y, colorDownConvert(c));
        }
      }
      
      image(img2, 10 + 120 + 10, 10 + 80 + 10);
    }
    catch (Exception e) {
      e.printStackTrace();
      JOptionPane.showMessageDialog(null, "Error while loading image: " + e.getMessage());
    }
  } else {
      println("???");
  }
}

boolean saveToBin(String fp)
{
  if (img2 == null) {
    JOptionPane.showMessageDialog(null, "Error: No Image Loaded");
    return false;
  }
  
  try {
    FileOutputStream fstream = new FileOutputStream(fp);
    BufferedOutputStream bstream = new BufferedOutputStream(fstream);
    DataOutputStream dstream = new DataOutputStream(bstream);
    
    // first 2 bytes indicate size
    dstream.writeShort(imgW);
    for (int x = 0; x < imgW; x++)
    {
      for (int y = 0; y < 8; y++)
      {
        color c = img2.get(x * 10, y * 10);
        byte b = colorToByte(c);
        dstream.writeByte(b);
      }
    }
    
    dstream.close();
    bstream.close();
    fstream.close();
    return true;
  }
  catch (Exception e) {
    e.printStackTrace();
    JOptionPane.showMessageDialog(null, "Error while writing file: " + e.getMessage());
    return false;
  }
}

public void saveBin(int val)
{
  if (!cp5_isReady) return;
  
  println("saveBin clicked");
  
  if (img2 == null) {
    JOptionPane.showMessageDialog(null, "Error: No Image Loaded");
    return;
  }
  
  final JFileChooser fc = new JFileChooser();
  try {
    fc.setCurrentDirectory(new File(prefs.get("LAST_FILECHOOSER_DIR", "")));
  } catch (Exception e) { 
    e.printStackTrace();
  }
  
  if (fc.showSaveDialog(this) == JFileChooser.APPROVE_OPTION)
  {
    String fp = fc.getSelectedFile().getPath();
    println("file: " + fp);
    
    prefs.put("LAST_FILECHOOSER_DIR", fc.getSelectedFile().getParent());
    
    saveToBin(fp);
  }
}

public void openBin(int val)
{
  if (!cp5_isReady) return;
  
  println("openBin clicked");
  
  final JFileChooser fc = new JFileChooser();
  try {
    fc.setCurrentDirectory(new File(prefs.get("LAST_FILECHOOSER_DIR", "")));
  } catch (Exception e) { 
    e.printStackTrace();
  }
  
  if (fc.showOpenDialog(this) == JFileChooser.APPROVE_OPTION)
  {
    String fp = fc.getSelectedFile().getPath();
    println("file: " + fp);
    
    prefs.put("LAST_FILECHOOSER_DIR", fc.getSelectedFile().getParent());
    
    background(0);
    
    try {
      FileInputStream fstream = new FileInputStream(fp);
      BufferedInputStream bstream = new BufferedInputStream(fstream);
      DataInputStream dstream = new DataInputStream(bstream);
      
      imgW = dstream.readShort();
      img2 = new PImage(imgW * 10, 80);
      for (int x = 0; x < imgW; x++)
      {
        for (int y = 0; y < 8; y++)
        {
          color c = byteToColor(dstream.readByte());
          for (int xx = 0; xx < 10; xx++) for (int yy = 0; yy < 10; yy++) img2.set((x * 10) + xx, (y * 10) + yy, c);
        }
      }
      
      img1 = img2;
      image(img1, 10 + 120 + 10, 10);
      image(img2, 10 + 120 + 10, 10 + 80 + 10);
      
      dstream.close();
      bstream.close();
      fstream.close();
    }
    catch (Exception e) {
      e.printStackTrace();
      JOptionPane.showMessageDialog(null, "Error while reading file: " + e.getMessage());
    }
  }
}

public void download(int val)
{
  if (!cp5_isReady) return;
  
  println("download clicked");
  
  if (img2 == null) {
    JOptionPane.showMessageDialog(null, "Error: No Image Loaded");
    return;
  }
  
  if (saveToBin("temp.bin"))
  {
    // use the VUsbTinyBoot bootloader, for ATmega328P, no fuse safemode, no auto-erase, no progress bar, write the temporary file to eeprom
    String[] cmd = { "avrdude", "-cusbtiny", "-pm328p", "-s", "-D", "-q", "-q", "-Ueeprom:w:temp.bin:r" };
    print("shell:");
    for (int i = 0; i < cmd.length; i++) print(" " + cmd[i]);
    println();
    Process p = open(cmd);
    String s = new String();
    try {
      p.waitFor();
      
      // read in everything that avrdude said back
      InputStream inStream = p.getInputStream();
      while (inStream.available() > 0) s += char(inStream.read());
      inStream = p.getErrorStream();
      while (inStream.available() > 0) s += char(inStream.read());
      
      println("done!");
      println(s);
    }
    catch (Exception e) {
      println("done! (interrupted)");
      println(s);
    }
    
    if (s.toLowerCase().contains("error")) {
      JOptionPane.showMessageDialog(null, "Possible Error Detected:\r\n" + s);
    }
    else {
      JOptionPane.showMessageDialog(null, "Done!\r\n" + s);
    }
    
    try {
      File f = new File("temp.bin");
      if (f.delete()) {
        println("temp.bin deleted");
      }
      else {
        println("temp.bin not deleted");
      }
    } catch (Exception e) {
      println("Exception while deleting temp.bin: " + e.getMessage());
    }
  }
}
