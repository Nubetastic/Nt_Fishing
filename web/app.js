const game = document.getElementById('game');
const target = document.getElementById('target');
const marker = document.getElementById('marker');
const progress = document.getElementById('progress');
const feedback = document.getElementById('feedback');
const fishingInfo = document.getElementById('fishing-info');
const fishGrid = document.getElementById('fish-grid');
const guideClose = document.getElementById('guide-close');
const guidePreferred = document.getElementById('guide-preferred');
const guideChances = document.getElementById('guide-chances');
const guideHow = document.getElementById('guide-how');
const guideTitle = document.getElementById('guide-title');
const guideSubtitle = document.getElementById('guide-subtitle');
const guideSummary = document.getElementById('guide-summary');
const guideDetails = document.getElementById('guide-details');
const guideHowTo = document.getElementById('guide-how-to');
const guideMissRule = document.getElementById('guide-miss-rule');
const catchMatrix = document.getElementById('catch-matrix');
const scaleSliders = document.querySelectorAll('.scale-slider');
const scaleValues = document.querySelectorAll('.scale-value');
const scalablePanels = document.querySelectorAll('.panel, .guide-panel');

const scaleStorageKey = 'nt_fishing_ui_scale';
const defaultUiScale = 1;
const minimumUiScale = 0.5;
const maximumUiScale = 2;
const uiScaleStep = 0.05;
const JUMP_DISTANCE_MULTIPLIER = 2;

let active = false;
let completed = false;
let infoActive = false;
let requiredWins = 3;
let requiredLosses = 3;
let maxRounds = 5;
let results = [];
let markerPosition = 0;
let markerDirection = 1;
let markerSpeed = 55;
let speedIncreasePerRound = 0;
let targetLeft = 40;
let targetWidth = 18;
let deadline = 0;
let lastFrame = 0;
let animationFrame = 0;

let struggleChance = 0;
let struggleDuration = 400;
let struggleDistanceMin = 3;
let struggleDistanceMax = 5;
let struggleCheckInterval = 1000;
let struggleCooldown = 1750;
let nextStruggleCheck = 0;
let struggleCooldownUntil = 0;
let struggling = false;
let struggleAnchor = 0;
let nextStruggleJump = 0;
let struggleJumpIndex = 0;
let struggleEndsAt = 0;
let jitterJumpTime = 100;
let struggleMethods = { jitter: true, reverse: true, jump: true };

function clamp(value, minimum, maximum) {
    return Math.min(Math.max(value, minimum), maximum);
}

function getMaximumUiScale() {
    let maximumScale = maximumUiScale;

    scalablePanels.forEach((panel) => {
        if (panel.offsetWidth === 0 || panel.offsetHeight === 0) return;

        maximumScale = Math.min(
            maximumScale,
            window.innerWidth / panel.offsetWidth,
            window.innerHeight / panel.offsetHeight,
        );
    });

    // Round down to a slider step so scaling can never push a panel past the viewport.
    return Math.max(minimumUiScale, Math.floor(maximumScale / uiScaleStep) * uiScaleStep);
}

function clampUiScale(value) {
    return Math.min(getMaximumUiScale(), Math.max(minimumUiScale, Number(value) || defaultUiScale));
}

function applyUiScale(value, shouldSave = false) {
    const scale = clampUiScale(value);
    const maximumScale = getMaximumUiScale();

    document.documentElement.style.setProperty('--ui-scale', scale.toFixed(2));
    scaleSliders.forEach((slider) => {
        slider.max = maximumScale.toFixed(2);
        slider.value = scale.toFixed(2);
    });
    scaleValues.forEach((output) => {
        output.textContent = `${Math.round(scale * 100)}%`;
    });

    if (shouldSave) {
        localStorage.setItem(scaleStorageKey, scale.toFixed(2));
    }
}

function randomBetween(minimum, maximum) {
    return minimum + Math.random() * (maximum - minimum);
}

function inventoryImage(filename) {
    return `https://cfx-nui-rsg-inventory/html/images/${encodeURIComponent(filename)}`;
}

function postNui(callback, body = {}) {
    return fetch(`https://${GetParentResourceName()}/${callback}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body),
    });
}

function randomizeTarget() {
    const sidePadding = 5;
    const availableWidth = Math.max(0, 100 - (sidePadding * 2) - targetWidth);
    targetLeft = sidePadding + Math.random() * availableWidth;
    target.style.left = `${targetLeft}%`;
    target.style.width = `${targetWidth}%`;
}

function renderProgress() {
    progress.replaceChildren();

    for (let index = 0; index < maxRounds; index += 1) {
        const icon = document.createElement('span');
        const result = results[index];
        icon.className = result || 'pending';
        icon.textContent = '*';
        icon.setAttribute('aria-label', result === 'hit' ? 'Success' : result === 'miss' ? 'Failure' : 'Pending');
        progress.appendChild(icon);
    }
}

function setFeedback(message, type = '') {
    feedback.textContent = message;
    feedback.className = `feedback ${type}`.trim();
}

function stopGameView() {
    active = false;
    completed = true;
    struggling = false;
    cancelAnimationFrame(animationFrame);
    game.classList.add('hidden');
    game.setAttribute('aria-hidden', 'true');
}

async function finish(result) {
    if (completed) return;
    stopGameView();

    try {
        await postNui('fishingResult', { result });
    } catch (_) {
        // Lua also has a client-side timeout and will safely close the attempt.
    }
}

function startStruggle(now) {
    if (!struggleMethods.jitter) return;

    struggling = true;
    struggleAnchor = markerPosition;
    struggleJumpIndex = 0;
    struggleEndsAt = now + struggleDuration;
    nextStruggleJump = now;
    setFeedback('The fish is struggling!', 'struggle');
    marker.classList.add('struggling');
}

function finishStruggle(now) {
    const finishRoll = Math.random() * 100;
    const finishChance = clamp(struggleChance, 0, 100);
    const halfFinishChance = finishChance / 2;

    if (finishRoll < halfFinishChance && struggleMethods.reverse) {
        markerDirection *= -1;
        setFeedback('The fish changed direction!', 'struggle');
    } else if (finishRoll >= halfFinishChance && finishRoll < finishChance && struggleMethods.jump) {
        const distance = struggleDistanceMax * JUMP_DISTANCE_MULTIPLIER;
        const possibleDirections = [];
        if (markerPosition - distance >= 0) possibleDirections.push(-1);
        if (markerPosition + distance <= 100) possibleDirections.push(1);
        const jumpDirection = possibleDirections.length > 0
            ? possibleDirections[Math.floor(Math.random() * possibleDirections.length)]
            : (markerPosition < 50 ? 1 : -1);
        markerPosition = clamp(markerPosition + (jumpDirection * distance), 0, 100);
        setFeedback('The fish pulled hard!', 'struggle');
    } else {
        setFeedback('Keep your rhythm');
    }

    struggling = false;
    marker.classList.remove('struggling');
    struggleCooldownUntil = now + struggleCooldown;
    nextStruggleCheck = struggleCooldownUntil + struggleCheckInterval;
}

function updateStruggle(now) {
    if (now >= struggleEndsAt) {
        finishStruggle(now);
        return;
    }

    if (now < nextStruggleJump) return;

    // Every struggle jitters backward and forward until its duration expires.
    const direction = struggleJumpIndex % 2 === 0 ? -markerDirection : markerDirection;
    const distance = randomBetween(struggleDistanceMin, struggleDistanceMax);
    markerPosition = clamp(struggleAnchor + (direction * distance), 0, 100);
    struggleJumpIndex += 1;
    nextStruggleJump = now + jitterJumpTime;
}

function maybeStartStruggle(now) {
    if (!struggleMethods.jitter || struggling || now < nextStruggleCheck || now < struggleCooldownUntil) return;

    nextStruggleCheck = now + struggleCheckInterval;
    if (Math.random() * 100 < struggleChance) {
        startStruggle(now);
    }
}

function animate(timestamp) {
    if (!active) return;

    if (!lastFrame) lastFrame = timestamp;
    const elapsed = Math.min((timestamp - lastFrame) / 1000, 0.05);
    lastFrame = timestamp;
    const now = Date.now();

    maybeStartStruggle(now);
    if (struggling) {
        updateStruggle(now);
    } else {
        markerPosition += markerDirection * markerSpeed * elapsed;
        if (markerPosition >= 100) {
            markerPosition = 100;
            markerDirection = -1;
        } else if (markerPosition <= 0) {
            markerPosition = 0;
            markerDirection = 1;
        }
    }

    marker.style.left = `${markerPosition}%`;

    if (now >= deadline) {
        finish('failed');
        return;
    }

    animationFrame = requestAnimationFrame(animate);
}

function countResult(type) {
    return results.reduce((total, result) => total + (result === type ? 1 : 0), 0);
}

function attemptHit() {
    if (!active || completed || results.length >= maxRounds) return;

    const insideTarget = markerPosition >= targetLeft && markerPosition <= targetLeft + targetWidth;
    results.push(insideTarget ? 'hit' : 'miss');
    renderProgress();

    const wins = countResult('hit');
    const losses = countResult('miss');
    if (insideTarget) {
        setFeedback('Good hook!', 'hit');
        if (wins >= requiredWins) {
            finish('success');
            return;
        }
    } else {
        setFeedback(`Missed! ${requiredLosses - losses} chances left`, 'miss');
        if (losses >= requiredLosses) {
            finish('failed');
            return;
        }
    }

    if (results.length >= maxRounds) {
        finish(wins >= requiredWins ? 'success' : 'failed');
        return;
    }

    markerSpeed += speedIncreasePerRound;
    randomizeTarget();
}

function openGame(data) {
    closeFishingInfoView();

    requiredWins = Number(data.requiredWins) || 3;
    requiredLosses = Number(data.requiredLosses) || 3;
    maxRounds = Number(data.maxRounds) || 5;
    markerSpeed = Number(data.markerSpeed) || 55;
    speedIncreasePerRound = Number(data.speedIncreasePerRound) || 0;
    targetWidth = Number(data.targetWidth) || 18;
    struggleChance = Number(data.struggleChance) || 0;
    struggleDuration = Number(data.struggleDuration) || 400;
    struggleDistanceMin = Number(data.struggleDistanceMin) || 3;
    struggleDistanceMax = Number(data.struggleDistanceMax) || 5;
    struggleCheckInterval = Number(data.struggleCheckInterval) || 1000;
    struggleCooldown = Number(data.struggleCooldown) || 1750;
    jitterJumpTime = Math.max(1, Number(data.jitterJumpTime) || 100);
    struggleMethods = {
        jitter: data.struggleMethods?.jitter === true,
        reverse: data.struggleMethods?.reverse === true,
        jump: data.struggleMethods?.jump === true,
    };

    results = [];
    markerPosition = 0;
    markerDirection = 1;
    deadline = Date.now() + (Number(data.timeout) || 20000);
    nextStruggleCheck = Date.now() + struggleCheckInterval;
    struggleCooldownUntil = 0;
    struggling = false;
    lastFrame = 0;
    completed = false;
    active = true;

    marker.classList.remove('struggling');
    marker.style.left = '0%';
    randomizeTarget();
    renderProgress();
    setFeedback('Press SPACE in the green zone');
    game.classList.remove('hidden');
    game.setAttribute('aria-hidden', 'false');
    cancelAnimationFrame(animationFrame);
    animationFrame = requestAnimationFrame(animate);
}

function makeImage(filename, alt) {
    const wrapper = document.createElement('div');
    wrapper.className = 'item-image';

    const image = document.createElement('img');
    image.src = inventoryImage(filename);
    image.alt = alt;
    image.addEventListener('error', () => {
        image.classList.add('broken');
        wrapper.classList.add('missing');
    }, { once: true });

    wrapper.appendChild(image);
    return wrapper;
}

function renderFishGuide(fish) {
    fishGrid.replaceChildren();

    const fishList = Array.isArray(fish) ? fish : [];
    if (fishList.length === 0) {
        const empty = document.createElement('p');
        empty.className = 'empty-state';
        empty.textContent = 'No fish guide data is available.';
        fishGrid.appendChild(empty);
        return;
    }

    for (const entry of fishList) {
        const card = document.createElement('article');
        card.className = 'fish-card';

        const fishIdentity = document.createElement('div');
        fishIdentity.className = 'fish-identity';
        fishIdentity.appendChild(makeImage(entry.image, entry.name));

        const fishName = document.createElement('h2');
        fishName.textContent = entry.name;
        fishIdentity.appendChild(fishName);
        card.appendChild(fishIdentity);

        const preferredList = document.createElement('div');
        preferredList.className = 'preferred-list';
        for (const tackle of Array.isArray(entry.preferred) ? entry.preferred : []) {
            const preferred = document.createElement('div');
            preferred.className = 'preferred-item';
            preferred.appendChild(makeImage(tackle.image, tackle.name));

            const label = document.createElement('span');
            label.textContent = tackle.name;
            preferred.appendChild(label);
            preferredList.appendChild(preferred);
        }

        card.appendChild(preferredList);
        fishGrid.appendChild(card);
    }
}

function chanceClass(chance) {
    if (chance <= 0) return 'chance-none';
    if (chance < 35) return 'chance-low';
    if (chance < 70) return 'chance-medium';
    return 'chance-high';
}

function renderCatchMatrix(fish, tackle) {
    catchMatrix.replaceChildren();

    const tackleList = Array.isArray(tackle) ? tackle : [];
    const fishList = Array.isArray(fish) ? fish : [];
    if (tackleList.length === 0 || fishList.length === 0) {
        const body = document.createElement('tbody');
        const row = document.createElement('tr');
        const cell = document.createElement('td');
        cell.className = 'matrix-empty';
        cell.textContent = 'No catch chance data is available.';
        row.appendChild(cell);
        body.appendChild(row);
        catchMatrix.appendChild(body);
        return;
    }
    const head = document.createElement('thead');
    const headerRow = document.createElement('tr');
    const fishHeader = document.createElement('th');
    fishHeader.className = 'matrix-fish-heading';
    fishHeader.scope = 'col';
    fishHeader.textContent = 'Fish';
    headerRow.appendChild(fishHeader);

    for (const item of tackleList) {
        const heading = document.createElement('th');
        heading.scope = 'col';
        heading.className = 'matrix-tackle-heading';
        heading.appendChild(makeImage(item.image, item.name));

        const name = document.createElement('span');
        name.textContent = item.name;
        heading.appendChild(name);

        const type = document.createElement('small');
        type.textContent = item.type;
        heading.appendChild(type);
        headerRow.appendChild(heading);
    }

    head.appendChild(headerRow);
    catchMatrix.appendChild(head);

    const body = document.createElement('tbody');
    for (const entry of fishList) {
        const row = document.createElement('tr');
        const fishCell = document.createElement('th');
        fishCell.scope = 'row';
        fishCell.className = 'matrix-fish';
        fishCell.appendChild(makeImage(entry.image, entry.name));

        const fishName = document.createElement('span');
        fishName.textContent = entry.name;
        fishCell.appendChild(fishName);
        row.appendChild(fishCell);

        for (let index = 0; index < tackleList.length; index += 1) {
            const chance = Number(entry.chances?.[index]) || 0;
            const cell = document.createElement('td');
            cell.className = `catch-chance ${chanceClass(chance)}`;
            cell.textContent = chance > 0 ? String(chance) : '-';
            cell.setAttribute('aria-label', `${entry.name} with ${tackleList[index].name}: attraction score ${chance}`);
            row.appendChild(cell);
        }

        body.appendChild(row);
    }

    catchMatrix.appendChild(body);
}

function showGuideScreen(screen) {
    const screens = {
        preferred: {
            view: guideSummary,
            button: guidePreferred,
            title: 'PREFERRED BAIT',
            subtitle: 'Match the bait or lure to the fish you want.',
        },
        chances: {
            view: guideDetails,
            button: guideChances,
            title: 'ALL BAIT',
            subtitle: 'Compare every fish against every bait and lure.',
        },
        how: {
            view: guideHowTo,
            button: guideHow,
            title: 'HOW TO FISH',
            subtitle: 'From equipping your rod to landing the catch.',
        },
    };
    const selected = screens[screen] || screens.preferred;

    for (const entry of Object.values(screens)) {
        const isSelected = entry === selected;
        entry.view.classList.toggle('hidden', !isSelected);
        entry.button.classList.toggle('active', isSelected);
        entry.button.setAttribute('aria-pressed', String(isSelected));
    }

    guideTitle.textContent = selected.title;
    guideSubtitle.textContent = selected.subtitle;
}

function openFishingInfoView(data) {
    stopGameView();
    renderFishGuide(data.fish);
    renderCatchMatrix(data.fish, data.tackle);
    const lossLimit = Math.max(1, Number(data.requiredLosses) || 3);
    guideMissRule.textContent = `${lossLimit} ${lossLimit === 1 ? 'miss snaps' : 'misses snap'} the line and the fish escapes.`;
    showGuideScreen('preferred');
    infoActive = true;
    fishingInfo.classList.remove('hidden');
    fishingInfo.setAttribute('aria-hidden', 'false');
    applyUiScale(localStorage.getItem(scaleStorageKey) || defaultUiScale, true);
    guideClose.focus();
}

function closeFishingInfoView() {
    infoActive = false;
    fishingInfo.classList.add('hidden');
    fishingInfo.setAttribute('aria-hidden', 'true');
}

function requestCloseFishingInfo() {
    if (!infoActive) return;
    closeFishingInfoView();
    postNui('closeFishingInfo').catch(() => {});
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    switch (data.action) {
        case 'openFishingInfo':
            openFishingInfoView(data);
            break;
        case 'closeFishingInfo':
            closeFishingInfoView();
            break;
        case 'openGame':
            openGame(data);
            break;
        case 'closeGame':
            stopGameView();
            break;
        case 'closeAll':
            stopGameView();
            closeFishingInfoView();
            break;
        default:
            break;
    }
});

window.addEventListener('keydown', (event) => {
    if (infoActive && (event.code === 'Escape' || event.code === 'KeyR')) {
        event.preventDefault();
        requestCloseFishingInfo();
        return;
    }

    if (!active) return;
    if (event.code === 'Space') {
        event.preventDefault();
        attemptHit();
    } else if (event.code === 'Escape') {
        event.preventDefault();
        finish('cancelled');
    }
});

guideClose.addEventListener('click', requestCloseFishingInfo);
guidePreferred.addEventListener('click', () => showGuideScreen('preferred'));
guideChances.addEventListener('click', () => showGuideScreen('chances'));
guideHow.addEventListener('click', () => showGuideScreen('how'));
scaleSliders.forEach((slider) => {
    slider.addEventListener('input', () => applyUiScale(slider.value, true));
});

window.addEventListener('resize', () => {
    if (!infoActive) return;

    const currentScale = Number(getComputedStyle(document.documentElement).getPropertyValue('--ui-scale')) || defaultUiScale;
    applyUiScale(currentScale, true);
});

applyUiScale(localStorage.getItem(scaleStorageKey) || defaultUiScale);
