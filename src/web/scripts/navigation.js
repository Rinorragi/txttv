/**
 * TxtTV Navigation Script
 * Provides keyboard shortcuts and page navigation for local development
 * Target: Browser environment with modern ES6+ support
 * Version: 1.0.0
 */

(function() {
  'use strict';

  // === Configuration ===
  const CONFIG = {
    minPage: 100,
    maxPage: 110,
    defaultPage: 100,
    keybindings: {
      previous: ['ArrowLeft', 'p', 'P'],
      next: ['ArrowRight', 'n', 'N'],
      home: ['h', 'H', 'Home'],
      first: ['f', 'F'],
      last: ['l', 'L']
    }
  };

  // === Utility Functions ===
  
  /**
   * Get current page number from URL query string
   * @returns {number} Page number (100-110)
   */
  function getCurrentPage() {
    const params = new URLSearchParams(window.location.search);
    const page = parseInt(params.get('page'), 10);
    
    if (isNaN(page) || page < CONFIG.minPage || page > CONFIG.maxPage) {
      return CONFIG.defaultPage;
    }
    
    return page;
  }

  /**
   * Navigate to a specific page
   * @param {number} pageNumber - Target page number
   */
  function navigateToPage(pageNumber) {
    if (pageNumber < CONFIG.minPage || pageNumber > CONFIG.maxPage) {
      console.warn(`Page ${pageNumber} out of range [${CONFIG.minPage}-${CONFIG.maxPage}]`);
      return;
    }
    
    window.location.href = `?page=${pageNumber}`;
  }

  /**
   * Calculate previous page with wrapping
   * @param {number} currentPage - Current page number
   * @returns {number} Previous page number
   */
  function getPreviousPage(currentPage) {
    return currentPage === CONFIG.minPage ? CONFIG.maxPage : currentPage - 1;
  }

  /**
   * Calculate next page with wrapping
   * @param {number} currentPage - Current page number
   * @returns {number} Next page number
   */
  function getNextPage(currentPage) {
    return currentPage === CONFIG.maxPage ? CONFIG.minPage : currentPage + 1;
  }

  // === Keyboard Navigation ===
  
  /**
   * Handle keyboard events for navigation
   * @param {KeyboardEvent} event - Keyboard event object
   */
  function handleKeyPress(event) {
    // Ignore key presses when typing in input fields
    if (event.target.tagName === 'INPUT' || 
        event.target.tagName === 'TEXTAREA' ||
        event.target.isContentEditable) {
      return;
    }

    const currentPage = getCurrentPage();
    let targetPage = null;

    // Check which key was pressed
    if (CONFIG.keybindings.previous.includes(event.key)) {
      targetPage = getPreviousPage(currentPage);
    } else if (CONFIG.keybindings.next.includes(event.key)) {
      targetPage = getNextPage(currentPage);
    } else if (CONFIG.keybindings.home.includes(event.key)) {
      targetPage = CONFIG.defaultPage;
    } else if (CONFIG.keybindings.first.includes(event.key)) {
      targetPage = CONFIG.minPage;
    } else if (CONFIG.keybindings.last.includes(event.key)) {
      targetPage = CONFIG.maxPage;
    }

    if (targetPage !== null) {
      event.preventDefault();
      navigateToPage(targetPage);
    }
  }

  // === Performance Monitoring ===
  
  /**
   * Log page load performance metrics (development only)
   */
  function logPerformanceMetrics() {
    if (!window.performance || !window.performance.timing) {
      return;
    }

    window.addEventListener('load', function() {
      setTimeout(function() {
        const timing = performance.timing;
        const loadTime = timing.loadEventEnd - timing.navigationStart;
        const domReady = timing.domContentLoadedEventEnd - timing.navigationStart;
        
        console.log('[TxtTV] Performance Metrics:');
        console.log(`  Page Load: ${loadTime}ms`);
        console.log(`  DOM Ready: ${domReady}ms`);
        console.log(`  Current Page: ${getCurrentPage()}`);
      }, 0);
    });
  }

  // === Status Bar (if present) ===
  
  /**
   * Update status bar with current page info
   */
  function updateStatusBar() {
    const statusBar = document.querySelector('.status-bar');
    if (!statusBar) return;

    const currentPage = getCurrentPage();
    const pageNumberSpan = statusBar.querySelector('.page-number');
    
    if (pageNumberSpan) {
      pageNumberSpan.textContent = currentPage;
    }
  }

  // === Initialization ===
  
  /**
   * Initialize navigation system
   */
  function init() {
    // Set up keyboard navigation
    document.addEventListener('keydown', handleKeyPress);
    
    // Update status bar if present
    updateStatusBar();
    
    // Enable performance logging in development
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      logPerformanceMetrics();
    }

    // Log initialization
    console.log('[TxtTV] Navigation initialized', {
      currentPage: getCurrentPage(),
      pageRange: `${CONFIG.minPage}-${CONFIG.maxPage}`,
      keybindings: CONFIG.keybindings
    });
  }

  // Run initialization when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // === Public API (for debugging) ===
  window.TxtTvNavigation = {
    getCurrentPage,
    navigateToPage,
    getPreviousPage,
    getNextPage,
    version: '1.0.0'
  };

})();
