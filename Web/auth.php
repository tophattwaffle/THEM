<?php
    $code = $_GET['code'];
    $state = $_GET['state'];
    echo "<a href='#' id='code' onclick='copyToClipboard()'>". $code ."</a><br>";
    echo "State: " . $state;
?>
<div id='alert-message' style='display:none;color:green;margin-top:10px;' >Code copied to clipboard</div>
<script>
    function copyToClipboard() {
        var code = document.getElementById("code");
        var textArea = document.createElement("textarea");
        textArea.value = code.innerHTML;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand("copy");
        textArea.remove();
        document.getElementById("alert-message").style.display = "block";
    }
</script>
