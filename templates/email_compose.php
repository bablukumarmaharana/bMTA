<?php require_once __DIR__ . '/header.php';
$sm = new SenderManager($db);
$senders = $sm->getSenders($currentUser->currentUserId());
?>
<h2>Compose Email</h2>
<form method="post" action="queue-add" enctype="multipart/form-data">
    <input type="hidden" name="csrf_token" value="<?= Helpers::generateCsrf() ?>">
    <div class="row g-3">
        <div class="col-md-6">
            <select name="sender_id" class="form-control" required>
                <option value="">-- Select Sender --</option>
                <?php foreach ($senders as $s): ?>
                    <option value="<?= $s['id'] ?>"><?= $s['email'] ?> (<?= $s['name'] ?>)</option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="col-md-6">
            <input type="email" name="recipient" class="form-control" placeholder="recipient@example.com" required>
        </div>
        <div class="col-12">
            <input type="text" name="subject" class="form-control" placeholder="Subject" required>
        </div>
        <div class="col-12">
            <textarea name="body_text" class="form-control" rows="3" placeholder="Plain text version (optional)"></textarea>
        </div>
        <div class="col-12">
            <textarea name="body_html" class="form-control" rows="8" placeholder="HTML version (required)"></textarea>
        </div>
        <div class="col-12">
            <textarea name="amp_html" class="form-control" rows="5" placeholder="AMP HTML version (optional)"></textarea>
        </div>
        <div class="col-12">
            <h5>Custom Headers</h5>
            <div id="custom-headers-container">
                <div class="row mb-2 header-row">
                    <div class="col-md-5"><input type="text" name="header_names[]" class="form-control" placeholder="Header name"></div>
                    <div class="col-md-5"><input type="text" name="header_values[]" class="form-control" placeholder="Value"></div>
                </div>
            </div>
            <button type="button" class="btn btn-sm btn-outline-secondary" onclick="addComposeHeader()">+ Header</button>
        </div>
        <div class="col-12">
            <h5>Attachments</h5>
            <input type="file" id="fileUpload" class="form-control mb-2">
            <button type="button" class="btn btn-sm btn-outline-primary" onclick="uploadFile()">Upload</button>
            <ul id="attachedFiles" class="list-group mt-2"></ul>
            <input type="hidden" name="attachment_ids" id="attachmentIds">
        </div>
        <div class="col-12">
            <button type="submit" class="btn btn-lg btn-success">Queue Email</button>
        </div>
    </div>
</form>

<script>
function addComposeHeader() {
    let div = document.getElementById('custom-headers-container');
    let row = document.createElement('div');
    row.className = 'row mb-2 header-row';
    row.innerHTML = `<div class="col-md-5"><input type="text" name="header_names[]" class="form-control" placeholder="Header name"></div>
                     <div class="col-md-5"><input type="text" name="header_values[]" class="form-control" placeholder="Value"></div>
                     <div class="col-md-2"><button type="button" class="btn btn-danger btn-sm" onclick="this.parentNode.parentNode.remove()">X</button></div>`;
    div.appendChild(row);
}

function uploadFile() {
    let input = document.getElementById('fileUpload');
    if (!input.files[0]) return;
    let formData = new FormData();
    formData.append('file', input.files[0]);
    formData.append('csrf_token', '<?= Helpers::generateCsrf() ?>');
    fetch('attachment-upload', { method: 'POST', body: formData })
        .then(res => res.json())
        .then(data => {
            if (data.id) {
                let li = document.createElement('li');
                li.className = 'list-group-item d-flex justify-content-between';
                li.innerHTML = data.filename + ` <button type="button" class="btn btn-sm btn-danger" onclick="this.parentNode.remove(); updateIds()">Remove</button>`;
                li.dataset.id = data.id;
                document.getElementById('attachedFiles').appendChild(li);
                updateIds();
            }
        });
}
function updateIds() {
    let ids = Array.from(document.querySelectorAll('#attachedFiles li')).map(li => li.dataset.id);
    document.getElementById('attachmentIds').value = ids.join(',');
}
</script>
<?php require_once __DIR__ . '/footer.php'; ?>