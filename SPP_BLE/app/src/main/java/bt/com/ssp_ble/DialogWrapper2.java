package bt.com.ssp_ble;

import android.view.View;
import android.widget.AdapterView;
import android.widget.EditText;
import android.widget.RadioButton;
import android.widget.TextView;

//--------------------------------------------------------------------------
	 public class DialogWrapper2 {
			RadioButton rads[];
		    EditText Val[];
		    View base=null;public int nowsel;
		    String nomal[] = {"0000FFE0-0000-1000-8000-00805F9B34FB",
								"0000FFE1-0000-1000-8000-00805F9B34FB",
							"0000FFE1-0000-1000-8000-00805F9B34FB"};
	String bt16[] = {"0000FFE0-0000-1000-8000-00805F9B34FB",
			"0000FFE1-0000-1000-8000-00805F9B34FB",
			"0000FFE2-0000-1000-8000-00805F9B34FB"};
	String user[] = {"0000FFE0-0000-1000-8000-00805F9B34FB",
			"0000FFE1-0000-1000-8000-00805F9B34FB",
			"0000FFE1-0000-1000-8000-00805F9B34FB"};
		    DialogWrapper2(View base) {
		      this.base=base;rads = new RadioButton[3];Val = new EditText[3];
				Val[0] = (EditText)base.findViewById(R.id.setserviceuuid);
				Val[1] = (EditText)base.findViewById(R.id.setnotifyuuid);
				Val[2] = (EditText)base.findViewById(R.id.setwriteuuid);
				rads [0] = base.findViewById(R.id.rad1);
				rads [1] = base.findViewById(R.id.rad2);
				rads [2]=base.findViewById(R.id.rad3);
				rads[0].setOnClickListener(sel);
				rads[1].setOnClickListener(sel);
				rads[2].setOnClickListener(sel);
				setDefault(0);
				nowsel = 0;
		    }

	    private void setEdit(boolean en){
				Val[0].setEnabled(en);
				Val[1].setEnabled(en);
				Val[2].setEnabled(en);
			}

		public void setDefault(int d){
						if(d>3)return;
			nowsel = d;
			rads [0].setChecked(false);rads [1].setChecked(false);rads [2].setChecked(false);
			rads [d].setChecked(true);
			switch (d){
				case 0:setEdit(false); Val[0].setText(nomal[0]);Val[1].setText(nomal[1]);Val[2].setText(nomal[2]);break;
				case 1:setEdit(false); Val[0].setText(bt16[0]);Val[1].setText(bt16[1]);Val[2].setText(bt16[2]);break;
				case 2:setEdit(true); Val[0].setText(user[0]);Val[1].setText(user[1]);Val[2].setText(user[2]);break;
			}
		}

		private View.OnClickListener sel = new View.OnClickListener() {
			@Override
			public void onClick(View v) {
				switch (v.getId()){
					case R.id.rad1:setDefault(0);break;
					case R.id.rad2:setDefault(1);break;
					case R.id.rad3:setDefault(2);break;
				}
			}
		};

		public String[] getUUID(){
			String[] res = new String[3];
			res[0] = Val[0].getText().toString();
			res[1] = Val[1].getText().toString();
			res[2] = Val[2].getText().toString();

			return res;
		}

			public void seteditUUID(String[] uuid){
				user = uuid;
			}

		public String[] getusrUUID(){
			if(nowsel == 2){
				String[] res = new String[3];
				res[0] = Val[0].getText().toString();
				res[1] = Val[1].getText().toString();
				res[2] = Val[2].getText().toString();
				return res;
			}
			return user;
		}

		  }
