/*
 * Copyright (C) 2009 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package bt.com.ssp_ble;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothAdapter.LeScanCallback;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.app.ActivityCompat;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Set;

import static android.bluetooth.BluetoothDevice.DEVICE_TYPE_CLASSIC;
import static android.bluetooth.BluetoothDevice.DEVICE_TYPE_DUAL;
import static android.bluetooth.BluetoothDevice.DEVICE_TYPE_LE;

/**
 * This Activity appears as a dialog. It lists any paired devices and
 * devices detected in the area after discovery. When a device is chosen
 * by the user, the MAC address of the device is sent back to the parent
 * Activity in the result Intent.
 */
public class DeviceListActivity extends Activity {
	// Debug 
		private static final String TAG = "DeviceSearchActivity";
		private boolean D = false;
		
		// view
		private ListView mlvBTDevice;
		private Button mbtnReturn;
		private Button mbtnRefresh;
		private ProgressBar mprgBar;
		public static String EXTRAS_DEVICE ="Device";
		public static String EXTRAS_UART ="DeviceUART";
		public static String EXTRAS_TXO ="DeviceTXO";
		public static String EXTRAS_RXI ="DeviceRXI";
		public static String EXTRAS_TYPE ="DeviceTYPE";
		// adapter for le device list
		private LeDeviceListAdapter mLeDeviceListAdapter;
	   private BluetoothAdapter mBtAdapter;
		// bluetooth control
	    private BluetoothAdapter mBluetoothAdapter;
	    // Intent request codes
	 	private static final int REQUEST_ENABLE_BT = 1;
	 	private static final int REQUEST_CONNECT_DEVICE = 2;
	 	// Stops scanning after 5 seconds
	 	private static final long SCAN_PERIOD = 20000;
	    // status of ble scan
	    private boolean mScanning;
	    private Handler mHandler;
	    static Context mcontext;
	    EditText uart,txd,rxi;static Context mContext;
		@SuppressLint("NewApi")
		@Override
	    protected void onCreate(Bundle savedInstanceState) {
	        super.onCreate(savedInstanceState);
	        setContentView(R.layout.activity_devicesearch);
	        mHandler = new Handler();
	        mcontext = this;mContext = this;
	        final BluetoothManager bluetoothManager =
	                (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
	        mBluetoothAdapter = bluetoothManager.getAdapter();
			mBtAdapter = BluetoothAdapter.getDefaultAdapter();
	        // judge whether android have bluetooth
	        if(null == mBluetoothAdapter) {
	        	if(D) Log.e(TAG, "This device do not support Bluetooth");
	            Dialog alertDialog = new AlertDialog.Builder(this).
	                    setMessage("This device do not support Bluetooth").
	                    create();
	            alertDialog.show();
	            DeviceListActivity.this.finish();
	        }
	        uart = findViewById(R.id.serviceinput);
	        txd = findViewById(R.id.txinput);
	        rxi = findViewById(R.id.rxinput);
	        uart.setText(Read_config("uart"));
			txd.setText(Read_config("txo"));
			rxi.setText(Read_config("rxi"));

			// Register for broadcasts when a device is discovered
			IntentFilter filter = new IntentFilter(BluetoothDevice.ACTION_FOUND);
			this.registerReceiver(mReceiver, filter);
			// Register for broadcasts when discovery has finished
			filter = new IntentFilter(BluetoothAdapter.ACTION_DISCOVERY_FINISHED);
			this.registerReceiver(mReceiver, filter);
	        // ensure that Bluetooth exists
	        if (!EnsureBleExist()) {
	        	if(D) Log.e(TAG, "This device do not support BLE");
	        	finish();
	        }
	        
	        // device list initial
	        mlvBTDevice = (ListView)findViewById(R.id.lvBTDevices);
	        mlvBTDevice.setOnItemClickListener(new ItemClickEvent());


	        // return button initial
	        mbtnReturn = (Button)findViewById(R.id.about);
	        mbtnReturn.setOnClickListener(new OnClickListener() {
				
				@Override
				public void onClick(View arg0) {
					// TODO Auto-generated method stub
					if(D) Log.d(TAG, "return to the main activity");
					About(" ");
				}
			});

	        // refresh button initial
	        mbtnRefresh = (Button)findViewById(R.id.refresh);
	        mbtnRefresh.setOnClickListener(new OnClickListener() {
				
				@Override
				public void onClick(View arg0) {
					// TODO Auto-generated method stub
					if(D) Log.d(TAG, "refresh the data list");
					
					// clear the adapter
			    	mLeDeviceListAdapter.clear();
			    	
					// start the le scan
			    	if(false == mScanning) {
			    		ScanLeDevice(true);
			    	}
			    	
				}
			});
	        //mbtnRefresh.setVisibility(View.GONE);

	        // process bar initial
	        mprgBar = (ProgressBar)findViewById(R.id.progress_bar);
	        mprgBar.setVisibility(View.GONE);

			bleUUID = Read_LastUUID();

			if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
					!= PackageManager.PERMISSION_GRANTED) {
				//申请权限
				ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION},
						1);
			}else if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
					!= PackageManager.PERMISSION_GRANTED) {
				//申请权限
				ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_COARSE_LOCATION},
						2);
			}
			// Get a set of currently paired devices
			pairedDevices = mBtAdapter.getBondedDevices();

			// If there are paired devices, add each one to the ArrayAdapter
			Log.d("paitDevice",""+pairedDevices.size() );
			if (pairedDevices.size() > 0) {
				for (BluetoothDevice device : pairedDevices) {
					//mPairedDevicesArrayAdapter.add(device.getName() + "\n" + device.getAddress());
					Log.d("paitDevice",device.getName() + "\n" + device.getAddress());
				}
			}

	        
		}

	Set<BluetoothDevice> pairedDevices;
	@Override
	public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults);
		switch (requestCode) {
			case 1: // If request is cancelled, the result arrays are empty.
				if ((grantResults.length > 0)
						&& (grantResults[0] == PackageManager.PERMISSION_GRANTED));
				else Toast.makeText(this,"app没有定位权限将无法搜索蓝牙设备!",Toast.LENGTH_LONG);
				break;
			case 2: if ((grantResults.length > 0)
					&& (grantResults[0] == PackageManager.PERMISSION_GRANTED));
			else Toast.makeText(this,"app没有定位权限将无法搜索蓝牙设备!",Toast.LENGTH_LONG);
				break;
		}
	}
		
		// judge the support of ble in android  
	    private boolean EnsureBleExist() {
	        if (!getPackageManager().hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
	            Toast.makeText(this, "This device does not support BLE", Toast.LENGTH_LONG).show();
	            return false;
	        }
	        return true;
	    }	
	    
	    @Override
	    protected void onResume() {
	    	if(D) Log.d(TAG, "-------onResume-------");
	        super.onResume();

	        // Ensures Bluetooth is enabled on the device.  If Bluetooth is not currently enabled,
	        // fire an intent to display a dialog asking the user to grant permission to enable it.
	        if (!mBluetoothAdapter.isEnabled()) {
	            if (!mBluetoothAdapter.isEnabled()) {
	            	if(D) Log.d(TAG, "start bluetooth");
	                Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
	                startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT);
	            }
	        }

			// Get a set of currently paired devices
			pairedDevices = mBluetoothAdapter.getBondedDevices();
	        // Initializes list view adapter.
	        mLeDeviceListAdapter = new LeDeviceListAdapter();
	        // set the adapter
	        mlvBTDevice.setAdapter(mLeDeviceListAdapter);
	        // start le scan when activity is on
	        //ScanLeDevice(true);
	    }
	    
	    
	    private class ItemClickEvent implements OnItemClickListener {

			@Override
			public void onItemClick(AdapterView<?> l, View v, int position,
					long id) {
				// TODO Auto-generated method stub
				
				final BluetoothDevice device = mLeDeviceListAdapter.getDevice(position);
				if(D) Log.i(TAG, "select a device, the name is " + device.getName() + ", addr is " + device.getAddress());
		        if (device == null) return;
		        String Type =  mLeDeviceListAdapter.getDeviceType(position);
				// store the information for result
				Intent intent = new Intent(getApplicationContext(), MainActivity.class);
				intent.putExtra(EXTRAS_DEVICE, device);
				intent.putExtra(EXTRAS_TYPE, Type);
				Log.d("Type",Type);
		        if(Type.equals("[BLE]") || Type == "[BLE]"){
					intent.putExtra(EXTRAS_UART, bleUUID[0]);
					intent.putExtra(EXTRAS_RXI, bleUUID[1]);
					intent.putExtra(EXTRAS_TXO,bleUUID[2]);
				}
				startActivityForResult(intent, REQUEST_CONNECT_DEVICE);

			}
	    }
	    
	    @Override
	    protected void onPause() {
	    	if(D) Log.d(TAG, "-------onPause-------");
	    	
	    	// stop the le scan when close the activity
	    	if(true == mScanning) {
	    		ScanLeDevice(false);
	    	}
	    	// clear the adapter
	    	mLeDeviceListAdapter.clear();
	    	super.onPause();
	    }
	    @Override
		protected void onDestroy() {
		super.onDestroy();

		// Make sure we're not doing discovery anymore
		if (mBtAdapter != null) {
			mBtAdapter.cancelDiscovery();
		}

		// Unregister broadcast listeners
		this.unregisterReceiver(mReceiver);
	}

	private void doDiscovery() {
		if (D) Log.d(TAG, "doDiscovery()");
		// If we're already discovering, stop it
		if (mBtAdapter.isDiscovering()) {
			mBtAdapter.cancelDiscovery();
		}
		mBtAdapter.startDiscovery();
	}

	    // Control le scan
	    @SuppressLint("NewApi")
		private void ScanLeDevice(boolean enable) { 	
	    	//remove the stop le scan runnable
	    	mHandler.removeCallbacks(mStopLeScan);

	    	// control the process bar and le scan
	    	if(true == enable) {
				doDiscovery();
	    		// avoid repetition operator
	    		if(mScanning == enable) {
	    			if(D) Log.e(TAG, "the le scan is already on");
	    			return;
	    		}
	    		// Stops scanning after a pre-defined scan period.
	            mHandler.postDelayed(mStopLeScan, SCAN_PERIOD);
	            if(D) Log.d(TAG, "start the le scan, on time is " + SCAN_PERIOD + "ms");
	    		mBluetoothAdapter.startLeScan(mLeScanCallback);
	    		
	    		mprgBar.setVisibility(View.VISIBLE);
	    		mbtnRefresh.setVisibility(View.GONE);
	    	} else {
	    		// avoid repetition operator
	    		if(mScanning == enable) {
	    			if(D) Log.e(TAG, "the le scan is already off");
	    			return;
	    		}
	    		if(D) Log.d(TAG, "stop the le scan");
	    		mBluetoothAdapter.stopLeScan(mLeScanCallback);
	    		
	    		mprgBar.setVisibility(View.GONE);
	    		mbtnRefresh.setVisibility(View.VISIBLE);
	    	}
	    	// update le scan status
	    	mScanning = enable;
	    }

	    // Stops scanning after a pre-defined scan period.
	    Runnable mStopLeScan = new Runnable() {
	        @Override
	        public void run() {
	        	if(D) Log.d(TAG, "le delay time reached");
	        	// Stop le scan, delay SCAN_PERIOD ms
	        	ScanLeDevice(false);
	        }
	    };
	    
	    @SuppressLint("NewApi")
		private LeScanCallback mLeScanCallback = new LeScanCallback() {
			@Override
			public void onLeScan(final BluetoothDevice device, final int rssi, byte[] scanRecord) {
				// TODO Auto-generated method stub
				runOnUiThread(new Runnable() {
					@Override
					public void run() {
						// TODO Auto-generated method stub
						// add the device to the adaper
						Log.d(TAG, "find a ble device, name is " + device.getName()
											+ ", addr is " + device.getAddress() 
											+ "rssi is " + String.valueOf(rssi));

						// set the list item show information
			            final String deviceName = device.getName();
						if((device != null)&&(deviceName != null && deviceName.length() > 0)){
							if(true){
								//mLeDeviceListAdapter.addDevice(rssi, device,true);
								//mLeDeviceListAdapter.notifyDataSetChanged();
							}
						}
					} 
				});
			}
	    };

	// The BroadcastReceiver that listens for discovered devices and
	// changes the title when discovery is finished
	private final BroadcastReceiver mReceiver = new BroadcastReceiver() {
		@Override
		public void onReceive(Context context, Intent intent) {
			String action = intent.getAction();
			// When discovery finds a device
			if (BluetoothDevice.ACTION_FOUND.equals(action)) {
				// Get the BluetoothDevice object from the Intent
				BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
				int rssi = intent.getExtras().getShort(BluetoothDevice.EXTRA_RSSI);
				String deviceName = device.getName();
				if((device != null)&&(deviceName != null && deviceName.length() > 0)) {
					mLeDeviceListAdapter.addDevice(rssi, device);
					mLeDeviceListAdapter.notifyDataSetChanged();
				}
				// If it's already paired, skip it, because it's been listed already
				// if (device.getBondState() != BluetoothDevice.BOND_BONDED) {
				//if(mNewDevicesArrayAdapter.getPosition(device.getName() + "\n" + device.getAddress()) == -1){
				//	mNewDevicesArrayAdapter.add(device.getName() + "\n" + device.getAddress());
				//}
				// When discovery is finished, change the Activity title
			} else if (BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(action)) {
				//setProgressBarIndeterminateVisibility(false);
				//setTitle(R.string.select_device);
				//if (mNewDevicesArrayAdapter.getCount() == 0) {
				//	String noDevices = getResources().getText(R.string.none_found).toString();
				//	mNewDevicesArrayAdapter.add(noDevices);
				//}

				if(mLeDeviceListAdapter.getCount() == 0){
					//showTextToast("搜索不到设备，请确认是否开启了权限");
					if (ActivityCompat.checkSelfPermission(mContext, Manifest.permission.ACCESS_FINE_LOCATION)
							!= PackageManager.PERMISSION_GRANTED) {
						//申请权限
						ActivityCompat.requestPermissions((Activity) mContext, new String[]{Manifest.permission.ACCESS_FINE_LOCATION},
								1);
					}else if (ActivityCompat.checkSelfPermission((Activity) mContext, Manifest.permission.ACCESS_COARSE_LOCATION)
							!= PackageManager.PERMISSION_GRANTED) {
						//申请权限
						ActivityCompat.requestPermissions((Activity) mContext, new String[]{Manifest.permission.ACCESS_COARSE_LOCATION},
								2);
					}
				}
				//findViewById(R.id.button_scan).setVisibility(View.VISIBLE);
			}
		}
	};

	private static Toast toast = null;
	public static void showTextToast(String msg) {
		if (toast == null) {
			toast = Toast.makeText(mContext, msg, Toast.LENGTH_LONG);
			toast.setText(msg);
		} else {
			toast.setText(msg);
		}
		toast.show();
	}

	public void onActivityResult(int requestCode, int resultCode, Intent data)  {
	    	if(D) Log.d(TAG, "-------onActivityResult-------");
	    	if(D) Log.d(TAG, "onActivityResult " + resultCode);
	        switch (requestCode) {
	        
	        case REQUEST_ENABLE_BT:
		    	// When the request to enable Bluetooth returns 
		    	if (resultCode == Activity.RESULT_OK) {
		    		//do nothing
		            Toast.makeText(this, "Bt is enabled!", Toast.LENGTH_SHORT).show();            
		        } else {
		        	// User did not enable Bluetooth or an error occured
		        	Toast.makeText(this, "Bt is not enabled!", Toast.LENGTH_SHORT).show();
		        	finish();
		        }
		    	break;
		          
	        default:
	        	break;
	        }
	        super.onActivityResult(requestCode, resultCode, data);
	    }


	static String Save_config(String name,String Value){
		int diveceNum ;
		SharedPreferences  share = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
		Editor editor = share.edit();
		editor.putString(name, Value);
		editor.commit();
		return Value;
	}

	static void Save_lastSel(int sel){
		int diveceNum ;
		SharedPreferences  share = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
		Editor editor = share.edit();
		editor.putInt("lastUUIDsel",sel);
		editor.commit();
	}

	static int Read_lastSel( ){
		int diveceNum ;
		SharedPreferences config = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
		int sel = config.getInt("lastUUIDsel",0);
		if(sel>2)sel = 2;
		return sel;
	}

	static void Save_uerUUID(String[] uuid){
		SharedPreferences  share = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
		Editor editor = share.edit();
		editor.putString("useruuid0", uuid[0]);
		editor.putString("useruuid1", uuid[1]);
		editor.putString("useruuid2", uuid[2]);
		editor.commit();
	}

	String[] Read_UserUUID(){
		String[] uuid = new String[3];
		SharedPreferences config = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
		uuid[0] = config.getString("useruuid0", "0000FFE0-0000-1000-8000-00805F9B34FB");
		uuid[1] = config.getString("useruuid1", "0000FFE1-0000-1000-8000-00805F9B34FB");
		uuid[2] = config.getString("useruuid2", "0000FFE1-0000-1000-8000-00805F9B34FB");
		return uuid;
	}

	String[] Read_LastUUID(){
		String[] uuid = new String[3];
		SharedPreferences config = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
		uuid[0] = config.getString("Lastuuid0", "0000FFE0-0000-1000-8000-00805F9B34FB");
		uuid[1] = config.getString("Lastuuid1", "0000FFE1-0000-1000-8000-00805F9B34FB");
		uuid[2] = config.getString("Lastuuid2", "0000FFE1-0000-1000-8000-00805F9B34FB");
		return uuid;
	}

	static void Save_LastUUID(String[] uuid){
		SharedPreferences  share = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
		Editor editor = share.edit();
		editor.putString("Lastuuid0", uuid[0]);
		editor.putString("Lastuuid1", uuid[1]);
		editor.putString("Lastuuid2", uuid[2]);
		editor.commit();
	}

	static String Read_config(String name){
		SharedPreferences config = mcontext.getSharedPreferences("perference", MODE_PRIVATE);
		return config.getString(name, "");
	}



	private void About(String Title){

		LayoutInflater inflater=LayoutInflater.from(this);
		View addView=inflater.inflate(R.layout.add_editadd, null);
		final DialogWrapper wrapper=new DialogWrapper(addView);//SettingActivity.DialogWrapper(addView);

		new AlertDialog.Builder(this)
				.setTitle(Title)
				.setView(addView)
				.setPositiveButton(getResources().getText(R.string.butok),null)
				.show();
	}

	public static void goweb(){
		Uri uri = Uri.parse("https://shop184598174.taobao.com/?spm=a230r.7195193.1997079397.2.mbTivR");
		//startActivity(new Intent(Intent.ACTION_VIEW,uri));
		 Intent it = new Intent(Intent.ACTION_VIEW, uri);
		mcontext.startActivity(it);
	}

	String bleUUID[] = {"0000FFE0-0000-1000-8000-00805F9B34FB",
			"0000FFE1-0000-1000-8000-00805F9B34FB",
			"0000FFE1-0000-1000-8000-00805F9B34FB"};

	public void SetUUID(View v){
		SetUUID();
	}
	static AlertDialog diag;
	DialogWrapper2 wrapper; int autosendtime=50;
	private void SetUUID() {
		LayoutInflater inflater=LayoutInflater.from(this);
		View addView=inflater.inflate(R.layout.uuidset,null);
		wrapper = new DialogWrapper2(addView);//SettingActivity.DialogWrapper(addView);
		wrapper.seteditUUID(Read_UserUUID()); //
		wrapper.setDefault(Read_lastSel());
		diag = new AlertDialog.Builder(this)
				.setView(addView)
				.setPositiveButton(getResources().getText(R.string.butok),
						null)
				.show();
		diag.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				String[] uuid = wrapper.getUUID();
				Save_uerUUID(wrapper.getusrUUID());
				Save_lastSel(wrapper.nowsel);

				if(uuid.length != 3){
					showTextToast(getResources().getText(R.string.wrongUUID).toString());
					return;
				}
				String[] div = uuid[0].split("-");
				if(div.length != 5){
					showTextToast(getResources().getText(R.string.wrongUUID).toString());
					return;
				}
				if((div[0].length() != 8)||(div[1].length() != 4)||(div[2].length() != 4)||(div[3].length() != 4)||(div[4].length() != 12))
				{
					showTextToast(getResources().getText(R.string.wrongUUID).toString());
					return;
				}

				div = uuid[1].split("-");

				if(div.length != 5){
					showTextToast(getResources().getText(R.string.wrongUUID).toString());
					return;
				}

				if((div[0].length() != 8)||(div[1].length() != 4)||(div[2].length() != 4)||(div[3].length() != 4)||(div[4].length() != 12))
				{
					showTextToast(getResources().getText(R.string.wrongUUID).toString());
					return;
				}

				div = uuid[2].split("-");
				if(div.length != 5){
					showTextToast(getResources().getText(R.string.wrongUUID).toString());
					return;
				}
				if((div[0].length() != 8)||(div[1].length() != 4)||(div[2].length() != 4)||(div[3].length() != 4)||(div[4].length() != 12))
				{
					showTextToast(getResources().getText(R.string.wrongUUID).toString());
					return;
				}
				bleUUID = uuid;
				Save_LastUUID(bleUUID);
				diag.dismiss();
				Log.d("get uuid ", uuid[0] + "  "+uuid[1] + "  "+uuid[2]);
			}
		});
	}

	public int getIsP(BluetoothDevice ndevice){
		if (pairedDevices.size() > 0){
			for (BluetoothDevice device : pairedDevices) {
				//mPairedDevicesArrayAdapter.add(device.getName() + "\n" + device.getAddress());
				if(device.equals(ndevice)) {
					Log.e("paitDevice", device.getName() + "\n" + device.getAddress());
					return 10;
				}
			}

			Log.e("paitDevice",ndevice.getName() +"un parit--=");
		}

		return 0;
	}
//------------------------------------------------------------------------------------------------------------


	 // Adapter for holding devices found through scanning.
	    private class LeDeviceListAdapter extends BaseAdapter {
	        private ArrayList<BluetoothDevice> mLeDevices;
	        private ArrayList<Integer> mRssi;
	        private ArrayList<String> Type;
	        private ArrayList<Integer> paired;
	        //private HashMap<Integer, BluetoothDevice> mLeDevices;
	        private LayoutInflater mInflator;

	        public LeDeviceListAdapter() {
	            super();
	            mLeDevices = new ArrayList<BluetoothDevice>();
	            mRssi = new ArrayList<Integer>();
				Type = new ArrayList<String>();
				paired = new ArrayList<Integer>();
	            mInflator = DeviceListActivity.this.getLayoutInflater();
	        }

	        public void addDevice(int rssi, BluetoothDevice device) {
	        	String mType;boolean isduab=false;
	        	switch (device.getType()){
					case DEVICE_TYPE_CLASSIC:mType = "[SPP]";break;
					case DEVICE_TYPE_LE:mType = "[BLE]";break;
					case DEVICE_TYPE_DUAL:mType = "[BLE]";isduab = true;break;
					default:mType = "[UNKNOWN]";break;
				}
	            if(!mLeDevices.contains(device)) {
	            	if(isduab == true){
						mLeDevices.add(device);
						Type.add("[SPP]");
						mRssi.add(rssi);
						paired.add(getIsP(device));
						mLeDevices.add(device);
						Type.add("[BLE]");
						mRssi.add(rssi);
						paired.add(0);
					}else{
						mLeDevices.add(device);
						Type.add(mType);
						mRssi.add(rssi);
						if(mType.equals("[SPP]") || mType == "[SPP]" ){
							paired.add(getIsP(device));
						}else{
							paired.add(0);
						}
					}


	            }else{
	        		//int index = mLeDevices.indexOf(device);
					//mRssi.set(index,rssi);
					for(int i=0;i<mLeDevices.size();i++){
						if(mLeDevices.get(i).equals(device)){
							mRssi.set(i,rssi);
						}
					}
					Log.d("RSSI",device.getName() + "  " + rssi);

				}
	        }

	        public BluetoothDevice getDevice(int position) {
	            return mLeDevices.get(position);
	        }
	        public String getDeviceType(int pos){
	        	return Type.get(pos);
			}

	        public void clear() {
	            mLeDevices.clear();
				paired.clear();
				mRssi.clear();
				Type.clear();
	        }

	        @Override
	        public int getCount() {
	            return mLeDevices.size();
	        }

	        @Override
	        public Object getItem(int i) {
	            return mLeDevices.get(i);
	        }

	        @Override
	        public long getItemId(int i) {
	            return i;
	        }

	        @Override
	        public View getView(int i, View view, ViewGroup viewGroup) {
	            ViewHolder viewHolder;
	            // General ListView optimization code.
	            if (view == null) {
	                view = mInflator.inflate(R.layout.listitem_device, null);
	                viewHolder = new ViewHolder();
	                viewHolder.deviceAddress = (TextView) view.findViewById(R.id.device_address);
	                viewHolder.deviceName = (TextView) view.findViewById(R.id.device_name);
	                viewHolder.deviceRssi = (TextView) view.findViewById(R.id.device_rssi);
	                viewHolder.backG = (View)view.findViewById(R.id.backg);

	                view.setTag(viewHolder);
	            } else {
	                viewHolder = (ViewHolder) view.getTag();
	            }
	            
	            // get the device information
	            BluetoothDevice device = mLeDevices.get(i);
	            
	            // set the list item show information
	            final String deviceName = device.getName();
	            
	            if (deviceName != null && deviceName.length() > 0)
	                viewHolder.deviceName.setText(Get_Name(device.getAddress(),deviceName));
	            else
	                viewHolder.deviceName.setText(Get_Name(device.getAddress(),"unknown device"));
	            viewHolder.deviceAddress.setText(device.getAddress());
	            viewHolder.deviceRssi.setText(Type.get(i)+"  RSSI:"+String.valueOf(mRssi.get(i)));
				int ispair = paired.get(i);
	            if( ispair > 5){
					//viewHolder.backG.setBackgroundColor(0x5010ee10);
					Log.e("Getview","Set");
					viewHolder.deviceRssi.setTextColor(0xffff9501);
					viewHolder.deviceAddress.setTextColor(0xffff9501);
					viewHolder.deviceName.setTextColor(0xffff9501);
				}else {
					viewHolder.deviceRssi.setTextColor(0xffffffff);
					viewHolder.deviceAddress.setTextColor(0xffffffff);
					viewHolder.deviceName.setTextColor(0xffffffff);
					//viewHolder.backG.setBackgroundColor(0x0010ee10);
					Log.e("Getview","unSet");
				}
	            Log.e("Getview","now index " + i + "   val = "+ ispair + "    " + deviceName);
	            return view;
	        }
	    }
	    
	    static class ViewHolder {
	        TextView deviceName;
	        TextView deviceAddress;
	        TextView deviceRssi;
	        View backG;
	    }
	    
		static String Get_Name(String add,String dname){
			/*
			String name="";
			name = Read_config(add);
			if(name.length()<2){
				name = Save_config(add,dname);
			}
			return name;*/
			return dname;
		}

}
