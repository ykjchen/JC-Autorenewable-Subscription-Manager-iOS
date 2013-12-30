<?php
	/*
	* Change <<YOUR APPLE APP SECRET>> below to your autorenewable subscription
	* shared secret, which you can find in your iTunesConnect > Manage Apps.
	*/
	
	// Inputs
	$receiptdata = $_POST['receipt-data'];
	$sandbox = $_POST['sandbox'];
	
	$devmode;	
	if ($sandbox == 1) {
		$devmode = TRUE;
	} else {
		$devmode = FALSE;
	}

	// Processing
	$response = validate_receipt($receiptdata, $devmode);
	
	// Outputs
	$output = array('status' => $response['status']);

	$latest_receipt = $response['latest_receipt'];
	if ($latest_receipt) {
		$output['latest_receipt'] = $latest_receipt;
	}
	
	$expires_date = $response['receipt']['expires_date'];
	if ($expires_date) {
		$output['expires_date'] = $expires_date;
	}
	
	echo json_encode($output);

   /*
	* Source:
	* http://en.mfyz.com/integration-and-verification-of-ios-in-app-purchases
	*/
    function validate_receipt($receipt_data, $sandbox_receipt = FALSE) {
        if ($sandbox_receipt) {
            $url = "https://sandbox.itunes.apple.com/verifyReceipt";
        }
        else {
            $url = "https://buy.itunes.apple.com/verifyReceipt";
        }
        $ch = curl_init($url);
        $data_string = json_encode(array(
            'receipt-data' => $receipt_data,
            'password' => '<<YOUR APPLE APP SECRET>>',
        ));
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
        curl_setopt($ch, CURLOPT_POSTFIELDS, $data_string);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
        curl_setopt($ch, CURLOPT_HTTPHEADER, array(
            'Content-Type: application/json',
            'Content-Length: ' . strlen($data_string))
        );
        $output = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if (200 != $httpCode) {
            die("Error validating App Store transaction receipt. Response HTTP code $httpCode");
        }
        
        $decoded = json_decode($output, TRUE);
        return $decoded;
    }
?>

