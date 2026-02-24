/**
 * TXT TV Content Renderer
 * 
 * Fetches structured JSON content from the Content API and renders
 * it into the TXT TV page layout with category headers, severity
 * badges, content blocks, metadata, and navigation links.
 * 
 * Uses standard fetch() API per research.md Topic 4 decision.
 * 
 * Feature: 005-json-content-api (FR-006, FR-012, FR-015)
 */
(function () {
    'use strict';

    // ========================================================================
    // Configuration
    // ========================================================================
    var CONFIG = {
        contentEndpoint: '/content/',
        contentElementId: 'page-content',
        navPrevId: 'nav-prev',
        navNextId: 'nav-next',
        relatedContainerId: 'related-pages',
        metadataContainerId: 'page-metadata',
        categoryBadgeId: 'category-badge',
        severityBadgeId: 'severity-badge',
        defaultPage: 100,
        lineWidth: 45
    };

    // Severity color mapping for TXT TV style
    var SEVERITY_COLORS = {
        'CRITICAL': '#ff0000',
        'HIGH': '#ff8c00',
        'MEDIUM': '#ffcc00',
        'LOW': '#00ccff',
        'INFO': '#00ff00'
    };

    // ========================================================================
    // Page Number Extraction
    // ========================================================================

    /**
     * Extract page number from URL.
     * Supports: ?page=N (query param) and /page/N or /content/N (path)
     */
    function getPageNumber() {
        // Try query parameter first (?page=N)
        var params = new URLSearchParams(window.location.search);
        var page = params.get('page');
        if (page && /^\d{3}$/.test(page)) {
            return page;
        }

        // Try path extraction (/page/N or /content/N)
        var pathMatch = window.location.pathname.match(/\/(?:page|content)\/(\d{3})$/);
        if (pathMatch) {
            return pathMatch[1];
        }

        // Try data attribute on page-content element
        var el = document.getElementById(CONFIG.contentElementId);
        if (el && el.dataset.pageNumber && /^\d{3}$/.test(el.dataset.pageNumber)) {
            return el.dataset.pageNumber;
        }

        // Try meta tag
        var meta = document.querySelector('meta[name="page-number"]');
        if (meta && meta.content && /^\d{3}$/.test(meta.content)) {
            return meta.content;
        }

        return String(CONFIG.defaultPage);
    }

    // ========================================================================
    // Content Rendering
    // ========================================================================

    /**
     * Build the category and severity header line
     */
    function renderHeader(data) {
        var parts = [];

        if (data.category) {
            parts.push(data.category);
        }
        if (data.severity) {
            parts.push('[' + data.severity + ']');
        }

        var header = parts.join(' ');
        var titleLine = data.title || 'Untitled';

        return header + '\n' +
            '═'.repeat(CONFIG.lineWidth) + '\n' +
            titleLine + '\n' +
            '─'.repeat(CONFIG.lineWidth);
    }

    /**
     * Build the metadata footer
     */
    function renderMetadata(data) {
        var lines = [];
        lines.push('─'.repeat(CONFIG.lineWidth));

        if (data.metadata) {
            var metaParts = [];
            if (data.severity) {
                metaParts.push('Severity: ' + data.severity);
            }
            if (data.metadata.cvss !== undefined && data.metadata.cvss !== null) {
                metaParts.push('CVSS: ' + data.metadata.cvss);
            }
            if (metaParts.length > 0) {
                lines.push(metaParts.join(' | '));
            }
            if (data.metadata.published) {
                lines.push('Published: ' + data.metadata.published);
            }
        }

        lines.push('─'.repeat(CONFIG.lineWidth));
        lines.push('Page ' + data.pageNumber);
        return lines.join('\n');
    }

    /**
     * Render the full page content into the DOM
     */
    function renderContent(data) {
        var contentEl = document.getElementById(CONFIG.contentElementId);
        if (!contentEl) {
            console.error('[TxtTV] Content element not found: #' + CONFIG.contentElementId);
            return;
        }

        // Build TXT TV formatted content
        var rendered = [
            renderHeader(data),
            '',
            data.content || '',
            '',
            renderMetadata(data)
        ].join('\n');

        contentEl.textContent = rendered;

        // Update page title
        document.title = 'TXT TV - Page ' + data.pageNumber;

        // Update severity badge color if element exists
        var severityEl = document.getElementById(CONFIG.severityBadgeId);
        if (severityEl && data.severity && SEVERITY_COLORS[data.severity]) {
            severityEl.style.color = SEVERITY_COLORS[data.severity];
            severityEl.textContent = data.severity;
        }

        // Update navigation links
        updateNavigation(data.navigation, data.pageNumber);
    }

    /**
     * Update navigation links (prev/next/related)
     */
    function updateNavigation(nav, currentPage) {
        if (!nav) return;

        // Update prev link
        var prevEl = document.getElementById(CONFIG.navPrevId);
        if (prevEl) {
            if (nav.prev !== null && nav.prev !== undefined) {
                prevEl.href = '?page=' + nav.prev;
                prevEl.textContent = '◄ Page ' + nav.prev;
                prevEl.style.visibility = 'visible';
            } else {
                prevEl.style.visibility = 'hidden';
            }
        }

        // Update next link
        var nextEl = document.getElementById(CONFIG.navNextId);
        if (nextEl) {
            if (nav.next !== null && nav.next !== undefined) {
                nextEl.href = '?page=' + nav.next;
                nextEl.textContent = 'Page ' + nav.next + ' ►';
                nextEl.style.visibility = 'visible';
            } else {
                nextEl.style.visibility = 'hidden';
            }
        }

        // Update related pages
        var relatedEl = document.getElementById(CONFIG.relatedContainerId);
        if (relatedEl && nav.related && nav.related.length > 0) {
            relatedEl.innerHTML = '';
            var label = document.createTextNode('Related: ');
            relatedEl.appendChild(label);

            nav.related.forEach(function (pageNum, i) {
                if (i > 0) {
                    relatedEl.appendChild(document.createTextNode(' | '));
                }
                var link = document.createElement('a');
                link.href = '?page=' + pageNum;
                link.textContent = 'Page ' + pageNum;
                link.className = 'related-link';
                relatedEl.appendChild(link);
            });
            relatedEl.style.display = 'block';
        } else if (relatedEl) {
            relatedEl.style.display = 'none';
        }
    }

    // ========================================================================
    // Error Display (FR-015)
    // ========================================================================

    /**
     * Display error in TXT TV style
     */
    function renderError(pageNumber, statusCode, message) {
        var contentEl = document.getElementById(CONFIG.contentElementId);
        if (!contentEl) return;

        var errorText = [
            'ERROR',
            '═'.repeat(CONFIG.lineWidth),
            '',
            message || 'An error occurred loading the page.',
            '',
            '─'.repeat(CONFIG.lineWidth),
            'Requested: Page ' + pageNumber,
            'Status: ' + (statusCode || 'Unknown'),
            '─'.repeat(CONFIG.lineWidth),
            '',
            'Press H for help, or navigate to another page.'
        ].join('\n');

        contentEl.textContent = errorText;
        document.title = 'TXT TV - Error';
    }

    // ========================================================================
    // Content Fetch
    // ========================================================================

    /**
     * Fetch and render content for a given page number
     */
    async function loadAndRenderContent(pageNumber) {
        var contentEl = document.getElementById(CONFIG.contentElementId);
        if (contentEl) {
            contentEl.textContent = 'Loading page ' + pageNumber + '...';
        }

        try {
            var response = await fetch(CONFIG.contentEndpoint + pageNumber);

            if (!response.ok) {
                if (response.status === 404) {
                    renderError(pageNumber, 404, 'Page ' + pageNumber + ' not found.\nThis page does not exist in the TXT TV system.');
                } else if (response.status === 400) {
                    renderError(pageNumber, 400, 'Invalid page number: ' + pageNumber + '\nPage numbers must be 3-digit integers (100-999).');
                } else {
                    renderError(pageNumber, response.status, 'Server error (' + response.status + ').\nPlease try again later.');
                }
                return;
            }

            var data = await response.json();

            // Basic validation of response structure
            if (!data || !data.pageNumber || !data.content) {
                renderError(pageNumber, null, 'Invalid content format received.\nThe server returned malformed data.');
                console.error('[TxtTV] Invalid JSON structure:', data);
                return;
            }

            renderContent(data);

        } catch (err) {
            renderError(pageNumber, null, 'Network error loading content.\nCheck your connection and try again.');
            console.error('[TxtTV] Content load failed:', err);
        }
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    function init() {
        var pageNumber = getPageNumber();
        console.log('[TxtTV] Loading content for page', pageNumber);
        loadAndRenderContent(pageNumber);
    }

    // Wait for DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    // Expose public API for navigation.js integration
    window.TxtTvContentRenderer = {
        loadPage: loadAndRenderContent,
        getPageNumber: getPageNumber
    };
})();
