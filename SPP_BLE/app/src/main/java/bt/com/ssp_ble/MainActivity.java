package bt.com.ssp_ble;

import android.app.Activity;
import android.app.AlertDialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.text.Html;
import android.util.Log;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.UnsupportedEncodingException;
import java.util.UUID;

import static bt.com.ssp_ble.DeviceListActivity.EXTRAS_DEVICE;
import static bt.com.ssp_ble.SpBLE.STATE_CONNECTED;

public class MainActivity extends Activity {

    public static final int MESSAGE_STATE_CHANGE = 1;
    public static final int MESSAGE_READ = 2;
    public static final int MESSAGE_WRITE = 3;
    public static final int MESSAGE_DEVICE_NAME = 4;
    public static final int MESSAGE_TOAST = 5;
    private String mConnectedDeviceName = null;
    // Local Bluetooth adapter
    private BluetoothAdapter mBluetoothAdapter = null;
    // Member object for the chat services
    private BluetoothChatService mChatService = null;
    public static final String DEVICE_NAME = "device_name";
    public static final String TOAST = "toast";

    String TAG = "CarControl";
    // Intent request codes
    private static final int REQUEST_CONNECT_DEVICE = 1;
    private static final int REQUEST_ENABLE_BT = 2;
    BluetoothDevice mdevice;
    static Context mcontext;
    int getRunclyc(){
        int count ;
        SharedPreferences share = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
        count = share.getInt("CountNum", 0);
        SharedPreferences.Editor editor = share.edit();
        count++;
        editor.putInt("CountNum", count);
        editor.commit();
        if(count>10){
            showTextToast("超过测试次数，请重新安装app!");
            finish();
        }
        return count;
    }

    SpBLE mBLE_Service;
    String UART_UUID,TXO_UUID,RXI_UUID,BT_Type;
    Button Connentbut;boolean BLEON;TextView btinf;
    UUID sevice,txo,rxi;String DeviceInfo;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        mcontext = this;
        Intent data = getIntent();
        btinf = findViewById(R.id.info);
        mdevice  = data.getParcelableExtra(EXTRAS_DEVICE);
        BT_Type = data.getStringExtra(DeviceListActivity.EXTRAS_TYPE);
        if(BT_Type.equals("[BLE]") || BT_Type == "[BLE]"){
            BLEON = true;
            UART_UUID = data.getStringExtra(DeviceListActivity.EXTRAS_UART);
            TXO_UUID = data.getStringExtra(DeviceListActivity.EXTRAS_TXO);
            RXI_UUID = data.getStringExtra(DeviceListActivity.EXTRAS_RXI);
            sevice = UUID.fromString(UART_UUID);
            txo = UUID.fromString(TXO_UUID);
            rxi = UUID.fromString(RXI_UUID);
            btinf.setText("  "+mdevice.getAddress() + "   BLE" );
            DeviceInfo = "  "+mdevice.getAddress() + "   BLE";
        }else {
            BLEON = false;
            btinf.setText("  "+mdevice.getAddress() + "   SPP" );
            DeviceInfo = "  "+mdevice.getAddress() + "   SPP";
        }
        ((TextView)findViewById(R.id.devicenam)).setText(mdevice.getName());

        msg_Text =(TextView)findViewById(R.id.Text1);
        mcontext = this;
        mLayout = (LinearLayout) findViewById(R.id.layout);
        mScrollView=(ScrollView)findViewById(R.id.sv);
        Connentbut = findViewById(R.id.connect);
        sptx = findViewById(R.id.txspeed);
        sprx = findViewById(R.id.rxspeed);
         ttx = findViewById(R.id.txcount);
         trx = findViewById(R.id.rxcount);
        ttx.setText("TX: 0");
        trx.setText("TX: 0");
        mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        if (mBluetoothAdapter == null) {
            //showTextToast("没有发现蓝牙模块,程序中止");
            finish();
            return;
        }
        mBLE_Service = new SpBLE(this,mHandler);
        delayStart = new Timer(100, new Runnable() {
            @Override
            public void run() {
                Try_Connect();
                delayStart.stop();
            }
        });
        delayStart.restart();

        CountT = new Timer(500, new Runnable() {
            @Override
            public void run() {
                updatecount();
            }
        });
        CountT.restart();

        autoSent = new Timer(50, new Runnable() {
            @Override
            public void run() {
                sendMessage(null);
            }
        });
        autoSent.stop();
        autosendtime = Read_Atime();
        ((TextView)findViewById(R.id.autost)).setText(autosendtime+" ms");
        //getRunclyc();
        //Connentbut.setText("正在连接.");
        RSSI = new Timer(1000, new Runnable() {
            @Override
            public void run() {
                if(mBLE_Service != null)
                    mBLE_Service.getRSSI();
            }
        });
        RSSI.stop();
        ((Button)findViewById(R.id.atxdata)).setText(getResources().getText(R.string.autos));

    }

    int txs=0,rxs=0,txcount=0,rxcount=0;
        Timer RSSI;
    private void updatecount(){
        sptx.setText("TX: "+(txs*2)+"B/s");
        sprx.setText("RX: "+(rxs*2)+"B/s");
        txs = 0;
        rxs = 0;
    }
    TextView sptx,sprx,ttx,trx;

    void Try_Connect(){
        if(mdevice == null)return;
        if(BLEON){
            if(mBLE_Service == null)return;
                if(mBLE_Service.getConnectionState() == 3){
                    mBLE_Service.disconnect();
                    return;
                }
                mBLE_Service.setUUID(sevice,txo,rxi);
                mBLE_Service.disconnect();
                mBLE_Service.connect(mdevice, this);
        }else {
            if(mChatService == null)return;
            if(mChatService.getState() == 3){
                mChatService.stop();
                return;
            }
            mChatService.connect(mdevice);

        }
    }


    Timer delayStart,CountT,autoSent;
    public void onclick(View v){
        switch (v.getId()){
            case R.id.mclear:
                txcount = 0;rxcount=0;
                ttx.setText("TX: "+txcount);
                trx.setText("RX: "+rxcount);
                msg_Text.setText("");break;
            case R.id.mback:
                act_end();break;
            case R.id.connect:
                Try_Connect();
                break;
            case R.id.txdata:
                sendMessage(null);
                break;
            case R.id.settime:
                if(autoSent.getIsTicking()){
                    autoSent.stop();
                    ((Button)findViewById(R.id.atxdata)).setText(getResources().getText(R.string.autos));
                }
                SendSeting(getString(R.string.setautos),String.valueOf(autosendtime));break;
            case R.id.atxdata:

                if(BLEON){
                    if(mBLE_Service.getConnectionState() != 3){
                        showTextToast(getString(R.string.connectf));
                        return;
                    }
                }else{
                    if(mChatService.getState() != 3){
                        showTextToast(getString(R.string.connectf));
                        return;
                    }
                }
                if(autoSent.getIsTicking()){
                    autoSent.stop();
                    ( (Button)findViewById(R.id.atxdata)).setText(getString(R.string.autos));
                }else{
                    if(autosendtime == 0){
                        showTextToast(getString(R.string.psetautos));
                        SendSeting(getString(R.string.setautos),String.valueOf(autosendtime));
                        return;
                    }
                    autoSent.setInterval(autosendtime);
                    autoSent.restart();
                    ( (Button)findViewById(R.id.atxdata)).setText(getString(R.string.stopsend));
                }

                break;
        }
    }
    private void StopAutosend(){
        if(autoSent.getIsTicking()){
            autoSent.stop();
            ( (Button)findViewById(R.id.atxdata)).setText(getString(R.string.autos));
        }
    }
    static void Save_Atime(int sel){
        int diveceNum ;
        SharedPreferences  share = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
        SharedPreferences.Editor editor = share.edit();
        editor.putInt("autosendtime",sel);
        editor.commit();
    }

    static int Read_Atime( ){
        int diveceNum ;
        SharedPreferences config = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
        int sel = config.getInt("autosendtime",50);
        return sel;
    }

    static String Save_config(String name,String Value){
        int diveceNum ;
        SharedPreferences  share = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
        SharedPreferences.Editor editor = share.edit();
        editor.putString(name, Value);
        editor.commit();
        return Value;
    }

    static String Read_config(String name){
        SharedPreferences config = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
        return config.getString(name, "");
    }
    private Toast toast = null;
    private void showTextToast(String msg) {
        if (toast == null) {
            toast = Toast.makeText(getApplicationContext(), msg, Toast.LENGTH_LONG);
            toast.setText(msg);
        } else {
            toast.setText(msg);
        }
        toast.show();
    }

    private long exittime;
    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        //按下键盘上返回按钮
        if(keyCode == KeyEvent.KEYCODE_BACK){
            if(System.currentTimeMillis() - exittime >1200) //
            {
                showTextToast(getString(R.string.clickaganstr));
                exittime = System.currentTimeMillis();
            }
            else
            {
                act_end();
            }
            return true;
        }else{
            return super.onKeyDown(keyCode, event);
        }
    }

    @Override
    public void onStart() {
        super.onStart();
        Log.e(TAG, "++ ON START ++");
        // If BT is not on, request that it be enabled.
        // setupChat() will then be called during onActivityResult
        if (!mBluetoothAdapter.isEnabled()) {
            Intent enableIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
            startActivityForResult(enableIntent, REQUEST_ENABLE_BT);
            // Otherwise, setup the chat session
        } else {
            if (mChatService == null) setupChat();
        }
    }

    private void act_end(){
        if (mChatService.getState() == 3) {
            new AlertDialog.Builder(this).setTitle(getString(R.string.waring)).setIcon(android.R.drawable.ic_menu_info_details)
                    .setMessage(getString(R.string.checkexit))
                    .setPositiveButton(getString(R.string.disconnect), new DialogInterface.OnClickListener() {

                        @Override
                        public void onClick(DialogInterface dialog, int which) {
                            //mChatService.stop();
                            finish();
                        }
                    })
                    .setNegativeButton(getString(R.string.canled), new DialogInterface.OnClickListener() {

                        @Override
                        public void onClick(DialogInterface dialog, int which) {
                        }
                    }).show();
        }else{
            //showTextToast("请手动关闭蓝牙以节省电能");
            finish();
        }
    }

    private void setupChat() {
        Log.d(TAG, "setupConnect()");
        // Initialize the BluetoothChatService to perform bluetooth connections
        mChatService = new BluetoothChatService(this, mHandler);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        // Stop the Bluetooth chat services
        if (mChatService != null) {
            mChatService.stop();
        }
        if(mBLE_Service!=null)
            mBLE_Service.disconnect();
        StopAutosend();
        Log.e(TAG, "--- ON DESTROY ---");
    }

    @Override
    public synchronized void onResume() {
        super.onResume();
        Log.e(TAG, "+ ON RESUME +");
        if (mChatService != null) {
            if (mChatService.getState() == BluetoothChatService.STATE_NONE) {
                // Start the Bluetooth chat services
                mChatService.start();
            }
        }
    }

    private final Handler mHandler = new Handler() {
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case MESSAGE_STATE_CHANGE:
                    Log.i(TAG, "MESSAGE_STATE_CHANGE: " + msg.arg1);
                    switch (msg.arg1) {
                        case BluetoothChatService.STATE_CONNECTED:
                            //btbut.setImageResource(R.drawable.bton);
                            Connentbut.setText(getString(R.string.discon));
                            ((TextView)findViewById(R.id.connectinfo)).setText(getString(R.string.connectOK));
                            if(BLEON)RSSI.restart();
                            break;
                        case BluetoothChatService.STATE_CONNECTING:
                           // Connentbut.setText("正在连接");
                            ((TextView)findViewById(R.id.connectinfo)).setText(getString(R.string.connecting));
                            break;
                        case BluetoothChatService.STATE_LISTEN:
                        case BluetoothChatService.STATE_NONE:
                            //btbut.setImageResource(R.drawable.btoff);
                            //mled.seticolor(0xffdd1010);
                            //mTitle.setText("请连接设备");//show_msg("请连接蓝牙");
                            ((TextView)findViewById(R.id.connectinfo)).setText(getString(R.string.disconnect));
                            Connentbut.setText(getString(R.string.reconnect));
                            RSSI.stop();
                            btinf.setText(DeviceInfo);
                            StopAutosend();
                            break;
                    }
                    break;
                case MESSAGE_WRITE:
                    byte[] wBuf = (byte[]) msg.obj;
                    //Display_Data(wBuf,msg.arg1,true);
                    txcount += msg.arg1;txs += msg.arg1;
                    ttx.setText("TX: "+txcount);
                    break;
                case MESSAGE_READ:
                    byte[] readBuf = (byte[]) msg.obj;
                    String readMessage = null;
                    rxcount += msg.arg1;rxs += msg.arg1;
                    trx.setText("RX: "+rxcount);
                    //Log.d(TAG,"data in +" + msg.arg1);
                    //mdecode(readBuf,msg.arg1);
                    Display_Data(readBuf,msg.arg1,false);
                    break;
                case MESSAGE_DEVICE_NAME:
                    // save the connected device's name
                    mConnectedDeviceName = msg.getData().getString(DEVICE_NAME);
                   // showTextToast("已连接到： "
                    //        + mConnectedDeviceName);

                    //mTitle.setText("已连接："+mConnectedDeviceName);
                    //show_msg("已连接到蓝牙："+mConnectedDeviceName);
                    break;
                case MESSAGE_TOAST:
                    showTextToast( msg.getData().getString(TOAST));
                    break;
                case 100:
                    btinf.setText(DeviceInfo+ " "+msg.arg1);
                    break;
                case 101:
                    switch (msg.arg1){
                        case 0:  showTextToast("Service Error");
                            ((TextView)findViewById(R.id.connectinfo)).setText("Service Error");
                        break;
                        case 1:  showTextToast("Enable Notify Fail!");
                            ((TextView)findViewById(R.id.connectinfo)).setText("EN NotifyFail!");
                            break;
                    }
                    break;
            }

        }
    };

    LinearLayout mLayout;TextView msg_Text;ScrollView mScrollView;

    private final Handler tHandler = new Handler();
    private Runnable mScrollToBottom = new Runnable() {
        @Override
        public void run() {
            int off = mLayout.getMeasuredHeight() - mScrollView.getHeight();
            if (off > 0) {
                mScrollView.scrollTo(0, off);
            }
        }
    };

    public void show_data(String t){
        if(msg_Text.getText().toString().length()>1000){
            String nstr = msg_Text.getText().toString();
            nstr = nstr.substring(t.length(),nstr.length());
            msg_Text.setText(nstr);
        }
        //msg_Text.append(Html.fromHtml(t));
        msg_Text.append(t);
        tHandler.post(mScrollToBottom);//更新Scroll
    }

    void Add_Sended(String st){

        String temp = "<font color='red'>"+st +"</font>";
        show_data(temp);
    }
    void Add_Readed(String st){
        String temp =  "<font color='blue'>"+st +"</font>";
        show_data(temp);
    }

    void Display_Data(byte[] dat,int len,boolean isSend){
        String msg = "";
        boolean hex = false;
        if(isSend){
            hex =((CheckBox) (findViewById(R.id.txhex))).isChecked();
        }else hex =((CheckBox) (findViewById(R.id.rxhex))).isChecked();

        if(hex) {
            try {
                msg = getHexString(dat, 0, len);
            } catch (UnsupportedEncodingException e) {
                throw new RuntimeException("Unsupported   encoding   type.");
            }
        }else {
            try{
                msg = new String(dat, 0, len,"GBK");
            }catch	(UnsupportedEncodingException   e){
                throw   new   RuntimeException("Unsupported   encoding   type.");
            }
        }
        show_data(msg);
        //if(isSend)Add_Sended(msg);
        //else Add_Readed(msg);
    }

    public void sendMessage(View v) {
        String message;
        // Check that we're actually connected before trying anything
        if(BLEON == false) {
            if (mChatService.getState() != BluetoothChatService.STATE_CONNECTED) {
                showTextToast(getString(R.string.connectf));
                return;
            }
        }else{
            if(mBLE_Service.getConnectionState() != STATE_CONNECTED){
                showTextToast(getString(R.string.connectf));
                return;
            }
        }
        message = ((EditText)findViewById(R.id.datain)).getText().toString();
        if(message == null)return;
        message.replaceAll(" ","");
        if(message.equals(""))return;
        if (message.length() > 0) {
            // Get the message bytes and tell the BluetoothChatService to write
            //byte[] send = message.getBytes();
            //String Encode = "gbk";
            byte[] send = null;
            /**/
            if(((CheckBox) (findViewById(R.id.txhex))).isChecked()!=true){
                try{
                    send = message.getBytes("GBK");
                }catch (UnsupportedEncodingException e) {
                    e.printStackTrace();
                }
            }else
            send=getStringhex(message);
            if(BLEON == false)
                mChatService.write(send);
            else mBLE_Service.Write(send);

            //Display_Data(send,send.length,true);
        }
    }

    static final char[] HEX_CHAR_TABLE = {
            '0', '1', '2', '3',
            '4', '5', '6', '7',
            '8', '9', 'A', 'B',
            'C', 'D', 'E', 'F'
    };

    public static String getHexString(byte[] raw,int offset,int count)
            throws UnsupportedEncodingException
    {
        StringBuffer hex = new StringBuffer();
        for (int i=offset;i<offset+count;i++) {
            int v = raw[i]& 0xFF;
            hex.append(HEX_CHAR_TABLE[v >>> 4]);
            hex.append(HEX_CHAR_TABLE[v & 0xF]);
            hex.append(" ");
        }
        return hex.toString();
    }

    public  byte[] getStringhex(String ST)
    {
        ST=ST.replaceAll(" ", "");
        //Log.v("getStringhex",ST);
        char[] buffer =ST.toCharArray();
        byte[] Byte = new byte[buffer.length/2];
        int index=0;
        int bit_st=0;
        for(int i=0;i<buffer.length;i++)
        {
            int v=(int)(buffer[i]&0xFF);

            if(((v>47)&&(v<58)) || ((v>64)&&(v<71)) || ((v>96)&&(v<103))){
                if(bit_st==0){
                    //Log.v("getStringhex","F True");
                    Byte[index]|= (getASCvalue(buffer[i])*16);
                    //Log.v("getStringhex",String.valueOf(Byte[index]));
                    bit_st=1;
                }else {
                    Byte[index]|= (getASCvalue(buffer[i]));
                    //Log.v("getStringhex","F false");
                    //Log.v("getStringhex",String.valueOf(Byte[index]));
                    bit_st=0;
                    index++;
                }
            }else if (v==32){
                //Log.v("getStringhex","spance");
                if(bit_st==0);
                else{
                    index++;
                    bit_st=0;
                }
            }else continue;
        }
        bit_st=0;
        return Byte;
    }

    public static byte getASCvalue(char in)
    {
        byte out=0;
        switch(in){
            case '0':out=0;break;
            case '1':out=1;break;
            case '2':out=2;break;
            case '3':out=3;break;
            case '4':out=4;break;
            case '5':out=5;break;
            case '6':out=6;break;
            case '7':out=7;break;
            case '8':out=8;break;
            case '9':out=9;break;
            case 'a':out=10;break;
            case 'b':out=11;break;
            case 'c':out=12;break;
            case 'd':out=13;break;
            case 'e':out=14;break;
            case 'f':out=15;break;
            case 'A':out=10;break;
            case 'B':out=11;break;
            case 'C':out=12;break;
            case 'D':out=13;break;
            case 'E':out=14;break;
            case 'F':out=15;break;
        }
        return out;
    }


    DialogWrapper wrapper; int autosendtime=50;
    private void SendSeting(String Title,String value) {
        LayoutInflater inflater=LayoutInflater.from(this);
        View addView=inflater.inflate(R.layout.add_editsen,null);
        wrapper = new DialogWrapper(addView);//SettingActivity.DialogWrapper(addView);
        wrapper.setnametext(value);
        new AlertDialog.Builder(this)
                .setTitle(Title)
                .setView(addView)
                .setPositiveButton(getString(R.string.butok),
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog,
                                                int whichButton) {
                                String str=wrapper.getTitleField().getText().toString();
                                Log.d("UI", "autosendtime: " + str);
                                if((str!=null)&&(str.length()>0)){
                                    autosendtime =Integer.valueOf(str).intValue();
                                    Log.d("UI", "this is number " + str);

                                    if(autosendtime!=0){
                                        autoSent.stop();
                                        autoSent.setInterval(autosendtime);
                                        //autoSent.start();
                                        ((TextView)findViewById(R.id.autost)).setText(autosendtime+" ms");
                                    }
                                    else {
                                        autoSent.stop();
                                        autosendtime=0;
                                        ((TextView)findViewById(R.id.autost)).setText(autosendtime+" ms");
                                    }
                                    Save_Atime(autosendtime);
                                }else{
                                   // showTextToast("修改失败\r\n请输入数字");
                                }/*//*/
                                Log.d("UI", "Dialog finish !");
                            }
                        })
                .setNegativeButton(getString(R.string.canled),
                        new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog,
                                                int whichButton) {
                                // ignore, just dismiss
                            }
                        })
                .show();
    }
}
