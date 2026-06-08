package bt.com.ssp_ble;

import android.app.Activity;
import android.app.AlertDialog.Builder;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;


public class acttitleActivity extends Activity{
	private Button mSendButton;
    EditText input;
	TextView text1;int Count = 3;
    @Override
    public void onCreate(Bundle savedInstanceState) {
    	//requestWindowFeature(Window.FEATURE_NO_TITLE);
    	super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_login);
        this.setTitle("欢迎使用...");
        mSendButton = (Button) findViewById(R.id.button);
        mSendButton.setOnClickListener(new OnClickListener() {
            public void onClick(View v) {
                timerout.stop();
                    Intent intent = new Intent();
                    intent.setClass(acttitleActivity.this, DeviceListActivity.class);
                    startActivity(intent);
                    acttitleActivity.this.finish();
            }
        });
        mSendButton.setText("进入应用　　" + Count);
        timerout = new Timer(1000, new Runnable() {
            @Override
            public void run() {
                Count--;
                mSendButton.setText("进入应用　　" + Count);
                if(Count == 0){
                    Intent intent = new Intent();
                    intent.setClass(acttitleActivity.this, DeviceListActivity.class);
                    startActivity(intent);
                    timerout.stop();
                    acttitleActivity.this.finish();

                }
            }
        });
        timerout.restart();
    }

    Timer timerout;
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

    @Override
    protected void onDestroy() {
    // TODO Auto-generated method stub
    super.onDestroy();
        timerout.stop();
    
    }

/*
    void Save_Passworld(String passw) {
        SharedPreferences share = this.getSharedPreferences("perference", MODE_PRIVATE);
        SharedPreferences.Editor editor = share.edit();
        editor.putString("Password", passw);
        editor.commit();
    }

    String Read_Passw(){
        SharedPreferences  share = this.getSharedPreferences("perference", MODE_PRIVATE);
        return share.getString("Password","1234");
    }
*/

}