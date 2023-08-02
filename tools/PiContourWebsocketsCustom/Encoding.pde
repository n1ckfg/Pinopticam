import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import javax.imageio.ImageIO;
import java.util.Base64;

// ~ ~ ~ ASCII ~ ~ ~
// http://ascii.cl/control-characters.htm
// https://stackoverflow.com/questions/36519977/how-to-convert-string-into-a-7-bit-binary
// http://www.dcode.fr/ascii-code
// https://forum.processing.org/one/topic/need-help-in-converting-data-types.html

byte[] readNBits(String str, int n) {
    byte[] bytes = new byte[str.length() * n];
    for (int i = 0; i < str.length(); i++) {
        char ch = str.charAt(i);
        assert ch < int(pow(2,n));
        for (int j = 0; j < n; j++) 
            bytes[i * n + j] = (byte) ((ch >> (n - j)) & 1);
    }
    return bytes;
}

String[] decodeNBits(byte[] b, int n) {
  ArrayList stringsL= new ArrayList();
  for (int i=0; i<b.length; i+=n) {
    String s = "";
    for (int j=0; j<n; j++) {
      s += b[i+j];
    }
    stringsL.add(getCharFromInt(s, n));
  }
  String[] strings = new String[stringsL.size()];
  for (int i=0; i<strings.length; i++) {
    strings[i] = (String) stringsL.get(i);
  }
  return strings;
}

String getCharFromInt(String s, int n) {
  String returns = "";   
  char nextChar;
  // We want [0, 7], [9, 16], etc (increment index by 9 if bytes are space-delimited).
  for (int i = 0; i <= s.length()-n; i += n+1) {
       nextChar = (char) Integer.parseInt(s.substring(i, i+n), 2);
       returns += nextChar;
  }
  return returns;
}

String[] splitByNum(String s, int n) {
    return s.split("(?<=\\G.{" + n + "})");
}

String[] splitByChar(String[] s, String delim) {
    return splitTokens(join(s, ""), delim);
}

// ~ ~ ~ BASE64 ~ ~ ~
// https://forum.processing.org/two/discussion/6958/pimage-base64-encode-and-decode
// https://www.mkyong.com/java/how-to-convert-byte-to-bufferedimage-in-java/
// https://stackoverflow.com/questions/2305966/why-do-i-get-the-unhandled-exception-type-ioexception

ByteArrayInputStream byteStreamFromBase64(String input) {
  byte[] decodedBytes = Base64.getDecoder().decode(input);
  return new ByteArrayInputStream(decodedBytes);
}

byte[] byteArrayFromBase64(String input) {
  return byteStreamFromBase64(input).readAllBytes();
}

PImage decodePImageFromBase64(String input) {
  PImage returns = null;
  try {
    ByteArrayInputStream in = byteStreamFromBase64(input);
    BufferedImage bImageFromConvert = ImageIO.read(in);
    BufferedImage convertedImg = new BufferedImage(bImageFromConvert.getWidth(), bImageFromConvert.getHeight(), BufferedImage.TYPE_INT_ARGB);
    convertedImg.getGraphics().drawImage(bImageFromConvert, 0, 0, null);
    returns = new PImage(convertedImg); 
  } catch (IOException ie) { }
  return returns;
}

String decodeStringFromBase64(String input) {
  String returns = null;
  ByteArrayInputStream in = byteStreamFromBase64(input);
  returns = in.toString();
  return returns;
}

color decodeColorFromBytes(byte[] readColorBytes) {
  byte[] bytesR = { readColorBytes[0], readColorBytes[1], readColorBytes[2], readColorBytes[3] };
  byte[] bytesG = { readColorBytes[4], readColorBytes[5], readColorBytes[6], readColorBytes[7] };
  byte[] bytesB = { readColorBytes[8], readColorBytes[9], readColorBytes[10], readColorBytes[11] };
  
  float r = asFloat(bytesR);
  float g = asFloat(bytesG);
  float b = asFloat(bytesB);
  
  color col = color(255);
  if (!Float.isNaN(r) && !Float.isNaN(g) && !Float.isNaN(b)) {
    col = color(r,g,b);
  }
  
  return col;  
}

ArrayList<PVector> decodePointsFromBytes(byte[] readPointsBytes) {
    ArrayList<PVector> points = new ArrayList<PVector>();
    
    for (int i = 0; i < readPointsBytes.length; i += 12) { //+=16) { 
      byte[] bytesX = { readPointsBytes[i], readPointsBytes[i+1], readPointsBytes[i+2], readPointsBytes[i+3] };
      byte[] bytesY = { readPointsBytes[i+4], readPointsBytes[i+5], readPointsBytes[i+6], readPointsBytes[i+7] };
      byte[] bytesZ = { readPointsBytes[i+8], readPointsBytes[i+9], readPointsBytes[i+10], readPointsBytes[i+11] };
      //byte[] bytesW = { readPointsBytes[i+12], readPointsBytes[i+13], readPointsBytes[i+14], readPointsBytes[i+15] };

      float x = asFloat(bytesX);
      float y = asFloat(bytesY);
      float z = asFloat(bytesZ);
      //float w = asFloat(bytesW);
      
      if (!Float.isNaN(x) && !Float.isNaN(y)) { // && !Float.isNaN(z)) {
        PVector p = new PVector(x, y, z);
        points.add(p);
        //println(p.x + ", " + p.y + ", " + p.z);
      }
    }
    
    return points;
}

color decodeColorFromBase64(String input) {
  return decodeColorFromBytes(byteArrayFromBase64(input));
}

ArrayList<PVector> decodePointsFromBase64(String input) {
  return decodePointsFromBytes(byteArrayFromBase64(input));
}

// https://stackoverflow.com/questions/4513498/java-bytes-to-floats-ints
int asInt(byte[] bytes) {
  return (bytes[0] & 0xFF) 
         | ((bytes[1] & 0xFF) << 8) 
         | ((bytes[2] & 0xFF) << 16) 
         | ((bytes[3] & 0xFF) << 24);
}

float asFloat(byte[] bytes) {
  return Float.intBitsToFloat(asInt(bytes));
}

// https://forum.processing.org/two/discussion/23446/saving-multi-dimensional-arrays
// https://forum.processing.org/one/topic/writing-and-reading-a-mixture-of-ints-and-float-to-from-a-file.html
void serializeFloats(float[] _floats, String _fileName) {
  try {
    java.io.FileOutputStream fileOut = new java.io.FileOutputStream(sketchPath("") + "/" + _fileName);
    java.io.ObjectOutputStream out = new java.io.ObjectOutputStream(fileOut);
    out.writeObject(_floats);
    out.close();
    fileOut.close();
  } catch(IOException i) {
    i.printStackTrace();
  }
}

// http://forum.arduino.cc/index.php?topic=180456.0
void floatsToBytes(float[] floats, String _fileName) {
  byte[] bytes = new byte[floats.length * 4];
  
  for(int i=0; i<floats.length; i++) {
    int fi = Float.floatToIntBits(floats[i]);
    bytes[(i*4)] = byte(fi & 0xFF);
    bytes[(i*4)+1] = byte((fi >> 8) & 0xFF);
    bytes[(i*4)+2] = byte((fi >> 16) & 0xFF);
    bytes[(i*4)+3] = byte((fi >> 24) & 0xFF);
  }
  
  saveBytes(_fileName, bytes);
}
